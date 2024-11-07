package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"text/tabwriter"

	"gopkg.in/yaml.v3"
)

// Define the structure for the dist section
type Dist struct {
	Module         string `yaml:"module"`
	Name           string `yaml:"name"`
	Description    string `yaml:"description"`
	Version        string `yaml:"version"`
	OutputPath     string `yaml:"output_path"`
	OtelcolVersion string `yaml:"otelcol_version"`
}

// Define the structure for each component entry (receivers, exporters, etc.)
type Component struct {
	Gomod string `yaml:"gomod"`
}

// Define the structure for the whole YAML file
type ComponentsConfig struct {
	Dist       Dist        `yaml:"dist"`
	Receivers  []Component `yaml:"receivers"`
	Exporters  []Component `yaml:"exporters"`
	Extensions []Component `yaml:"extensions"`
	Processors []Component `yaml:"processors"`
	Connectors []Component `yaml:"connectors"`
}

// extractComponentName extracts the component name from the gomod string
func extractComponentName(gomod string) string {
	parts := strings.Split(gomod, "/")
	if len(parts) > 0 {
		// The last part of the gomod contains version, so split by space to remove it
		component := parts[len(parts)-1]
		// Remove the version part if present (e.g., "receiver v0.107.0")
		component = strings.Split(component, " ")[0]
		return component
	}
	return gomod
}

// getDistributionConfig reads the manifest.yaml file and returns a ComponentsConfig struct
func getDistributionConfig(manifestFile string) (ComponentsConfig, error) {
	yamlFile, err := os.ReadFile(manifestFile)
	if err != nil {
		return ComponentsConfig{}, fmt.Errorf("error reading YAML file: %w", err)
	}

	var config ComponentsConfig
	err = yaml.Unmarshal(yamlFile, &config)
	if err != nil {
		return ComponentsConfig{}, fmt.Errorf("error parsing YAML: %w", err)
	}

	return config, nil
}

// getSupportedComponents returns a list of supported components from the manifest
func getSupportedComponents(config ComponentsConfig) []string {
	components := make([]string, 0, len(config.Receivers)+len(config.Exporters)+len(config.Extensions)+len(config.Processors)+len(config.Connectors))

	// Use a helper function to avoid repetition
	appendComponents := func(comps []Component) {
		for _, comp := range comps {
			components = append(components, extractComponentName(comp.Gomod))
		}
	}

	// Append components from each category
	appendComponents(config.Receivers)
	appendComponents(config.Exporters)
	appendComponents(config.Extensions)
	appendComponents(config.Processors)
	appendComponents(config.Connectors)

	return components
}

// Define the structure to match the YAML file structure
type Metadata struct {
	Type   string `yaml:"type"`
	Status struct {
		Class     string    `yaml:"class"`
		Stability Stability `yaml:"stability"`
	} `yaml:"status"`
}

type Stability struct {
	Unmaintained []string `yaml:"unmaintained"`
	Deprecated   []string `yaml:"deprecated"`
	Alpha        []string `yaml:"alpha"`
	Development  []string `yaml:"development"`
	Beta         []string `yaml:"beta"`
	Stable       []string `yaml:"stable"`
}

// parseYAMLFile parses a metadata.yaml file and returns a Metadata struct
func parseYAMLFile(filepath string) (*Metadata, error) {
	data, err := os.ReadFile(filepath)
	if err != nil {
		return nil, fmt.Errorf("failed to read file: %w", err)
	}

	var m Metadata
	err = yaml.Unmarshal(data, &m)
	if err != nil {
		return nil, fmt.Errorf("failed to parse YAML: %w", err)
	}

	return &m, nil
}

// findMetadataFiles walks through directories and finds all metadata.yaml files
func findMetadataFiles(rootDir string, manifest ComponentsConfig) ([]string, error) {
	supportedComponents := getSupportedComponents(manifest)

	var files []string
	err := filepath.WalkDir(rootDir, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() || d.Name() != "metadata.yaml" {
			return nil
		}

		compName := filepath.Base(filepath.Dir(path))
		if slices.Contains(supportedComponents, compName) {
			files = append(files, path)
			return nil
		}

		return nil
	})

	if err != nil {
		return nil, err
	}

	return files, nil
}

// getSupportLevel gets the support level for the given category
func getSupportLevel(stability *Stability, category string) string {
	if contains(stability.Unmaintained, category) {
		return "Unmaintained"
	}
	if contains(stability.Deprecated, category) {
		return "Deprecated"
	}
	if contains(stability.Stable, category) {
		return "Stable"
	}
	if contains(stability.Beta, category) {
		return "Beta"
	}
	if contains(stability.Development, category) {
		return "Development"
	}
	if contains(stability.Alpha, category) {
		return "Alpha"
	}
	return "n/a"
}

// Helper function to check if a slice contains a specific category
func contains(slice []string, item string) bool {
	for _, v := range slice {
		if v == item {
			return true
		}
	}
	return false
}

func processMetadataFiles(files []string) map[string][]*Metadata {
	componentsByClass := make(map[string][]*Metadata)
	for _, file := range files {
		sg, err := parseYAMLFile(file)
		if err != nil {
			log.Printf("Failed to parse %s: %v\n", file, err)
			continue
		}
		if sg.Type == "" {
			log.Printf("Skipping invalid component in file %s: missing type\n", file)
			continue
		}
		class := sg.Status.Class
		componentsByClass[class] = append(componentsByClass[class], sg)
	}
	return componentsByClass
}

func printComponentTable(componentType, header string, components []*Metadata, getSupportFunc func(*Metadata) string) {
	w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', tabwriter.Debug)
	fmt.Println(strings.Repeat("=", len(header)))
	fmt.Println(componentType)
	fmt.Println(strings.Repeat("=", len(header)))
	fmt.Fprintln(w, header)

	for _, component := range components {
		support := getSupportFunc(component)
		fmt.Fprintf(w, "%s\t%s\n", component.Type, support)
	}
	w.Flush()
	fmt.Println()
}

func main() {
	manifestPath := flag.String("m", "manifest.yaml", "Specify the path to the manifest.yaml file")
	flag.Parse()

	repos := []string{
		"opentelemetry-collector",
		"opentelemetry-collector-contrib",
	}

	pwd, err := os.Getwd()
	if err != nil {
		log.Fatalln(err)
	}

	metadataFiles := []string{}

	for _, repo := range repos {
		manifest, err := getDistributionConfig(*manifestPath)
		if err != nil {
			log.Fatalf("Error getting distribution config: %v", err)
		}

		if _, err := os.Stat(filepath.Join(pwd, repo)); os.IsNotExist(err) {
			log.Printf("Repository %s does not exist, cloning...\n", repo)
			err := exec.Command("git", "clone", fmt.Sprintf("https://github.com/open-telemetry/%s.git", repo)).Run()
			if err != nil {
				log.Fatalf("Error cloning repository %s: %v", repo, err)
			}
		}

		log.Printf("Checking out version %s of %s\n", manifest.Dist.OtelcolVersion, repo)
		c := exec.Command("git", "checkout", fmt.Sprintf("v%s", manifest.Dist.OtelcolVersion))
		c.Dir = filepath.Join(pwd, repo)
		err = c.Run()
		if err != nil {
			log.Fatalf("Error checking out version %s of %s: %v", manifest.Dist.OtelcolVersion, repo, err)
		}

		// Find all metadata.yaml files in subdirectories
		f, err := findMetadataFiles(filepath.Join(pwd, repo), manifest)
		if err != nil {
			log.Fatalf("Error finding YAML files: %v", err)
		}
		metadataFiles = append(metadataFiles, f...)
	}

	componentsByClass := processMetadataFiles(metadataFiles)

	for class, components := range componentsByClass {
		if class == "connector" || class == "extension" {
			continue
		}
		printComponentTable(class, "Component Name\tTraces Support\tMetrics Support\tLogs Support", components, func(c *Metadata) string {
			tracesSupport := getSupportLevel(&c.Status.Stability, "traces")
			metricsSupport := getSupportLevel(&c.Status.Stability, "metrics")
			logsSupport := getSupportLevel(&c.Status.Stability, "logs")
			return fmt.Sprintf("%s\t%s\t%s", tracesSupport, metricsSupport, logsSupport)
		})
	}

	// Create a tab writer to display the output in table format
	w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', tabwriter.Debug)

	// Print the table headers
	header := "Component Name\tTraces to traces\tTraces to metrics\tTraces to logs\tMetrics to metrics\tMetrics to traces\tMetrics to logs\tLogs to logs\tLogs to traces\tLogs to metrics"
	fmt.Println(strings.Repeat("=", len(header)))
	fmt.Println("connectors")
	fmt.Println(strings.Repeat("=", len(header)))

	fmt.Fprintln(w, header)
	for _, component := range componentsByClass["connector"] {
		tracesToTraces := getSupportLevel(&component.Status.Stability, "traces_to_traces")
		tracesToMetrics := getSupportLevel(&component.Status.Stability, "traces_to_metrics")
		tracesToLogs := getSupportLevel(&component.Status.Stability, "traces_to_logs")

		metricsToMetrics := getSupportLevel(&component.Status.Stability, "metrics_to_metrics")
		metricsToTraces := getSupportLevel(&component.Status.Stability, "metrics_to_traces")
		metricsToLogs := getSupportLevel(&component.Status.Stability, "metrics_to_logs")

		logsToLogs := getSupportLevel(&component.Status.Stability, "logs_to_logs")
		logsToTraces := getSupportLevel(&component.Status.Stability, "logs_to_traces")
		logsToMetrics := getSupportLevel(&component.Status.Stability, "logs_to_metrics")

		fmt.Fprintf(w, "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", component.Type, tracesToTraces, tracesToMetrics, tracesToLogs, metricsToMetrics, metricsToTraces, metricsToLogs, logsToLogs, logsToTraces, logsToMetrics)
	}
	w.Flush()

	fmt.Println()

	// Create a tab writer to display the output in table format
	w = tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', tabwriter.Debug)

	// Print the table headers
	printComponentTable("extensions", "Component Name\tSupport", componentsByClass["extension"], func(c *Metadata) string {
		return getSupportLevel(&c.Status.Stability, "extension")
	})
	w.Flush()
}
