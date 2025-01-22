#!/bin/bash

# Define the required service names
required_service_names=("telemetrygen-http-blue" "telemetrygen-http-red" "telemetrygen-http-green")

# Get the list of pods with the specified label
pods=$(oc get pods -n chainsaw-lb -l app.kubernetes.io/name=chainsaw-lb-backends-collector -o jsonpath="{.items[*].metadata.name}")

# Initialize an empty string to hold all service names from all pods
all_service_names=""

for pod in $pods; do
  echo "Checking pod: $pod"

  # Get the logs of the pod
  logs=$(oc -n chainsaw-lb logs $pod)

  # Extract the unique service.name values from the logs
  service_names=$(echo "$logs" | grep -i "service.name" | awk -F': ' '{print $2}' | sort | uniq)

  # Check if a service.name is found in a pod, it should not be present in another pod
  for service_name in $service_names; do
    if echo "$all_service_names" | grep -q "$service_name"; then
      echo "Error: Service name $service_name found in more than one pod"
      exit 1
    else
      all_service_names+="$service_name "
      echo "Service.name $service_name found in pod $pod"
    fi
  done
done

# Check if all required service names are present in all_service_names
for required_service_name in "${required_service_names[@]}"; do
  if ! echo "$all_service_names" | grep -q "$required_service_name"; then
    echo "Error: Required service name $required_service_name is missing in the logs"
    exit 1
  fi
done

echo "All required service names are present in the logs of all pods"