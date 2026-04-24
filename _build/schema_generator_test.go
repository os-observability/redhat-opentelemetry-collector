package main

import (
	"os"
	"testing"

	"github.com/pavolloffay/opentelemetry-mcp-server/modules/collectorschema/schemagen"
)

func TestGenerateSchemas(t *testing.T) {
	schemaOutputDir := os.Getenv("SCHEMA_OUTPUT_DIR")
	if schemaOutputDir == "" {
		t.Fatal("SCHEMA_OUTPUT_DIR environment variable is required")
	}

	factories, err := components()
	if err != nil {
		t.Fatalf("Failed to get components: %v", err)
	}

	generator := schemagen.NewCollectorSchemaGenerator(schemaOutputDir, "vendor")

	if err := generator.GenerateFromFactories(factories); err != nil {
		t.Fatalf("Failed to generate schemas: %v", err)
	}

	if err := generator.CopyReadmeFiles(factories); err != nil {
		t.Fatalf("Failed to copy README files: %v", err)
	}

	t.Logf("Successfully generated YAML schemas in directory: %s", schemaOutputDir)
}
