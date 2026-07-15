package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

func main() {
	servicesPath := "services"
	outputPath := "./"

	composeFileName := filepath.Join(outputPath, "docker-compose.yml")
	if err := generateDockerComposeFile(servicesPath, composeFileName); err != nil {
		fmt.Printf("Error generating docker-compose for %s\n", err)
		return
	}
	fmt.Printf("Generated docker-compose at %s\n", composeFileName)
}

func generateDockerComposeFile(servicesPath, outputFileName string) error {
	var sb strings.Builder
	sb.WriteString("services:\n\n")

	serviceFiles, err := os.ReadDir(servicesPath)
	if err != nil {
		return err
	}

	for _, file := range serviceFiles {
		if file.IsDir() {
			continue
		}
		if strings.HasPrefix(file.Name(), "?") {
			continue
		}

		serviceFile := filepath.Join(servicesPath, file.Name())
		content, err := os.ReadFile(serviceFile)
		if err != nil {
			return err
		}

		// Add service content
		indentedContent := addIndentation(string(content))
		sb.Write([]byte(indentedContent))
		sb.WriteString("\n")
	}

	// Add networks and volumes
	sb.WriteString("networks:\n  common:\n    name: common\n    driver: bridge\n")

	composeContent := sb.String()
	return os.WriteFile(outputFileName, []byte(composeContent), 0644)
}

func addIndentation(content string) string {
	lines := strings.Split(content, "\n")
	var sb strings.Builder
	for i, line := range lines {
		if strings.TrimSpace(line) != "" {
			sb.WriteString("  ") // Add two spaces indentation
		}
		sb.WriteString(line)
		if i < len(lines)-1 {
			sb.WriteString("\n")
		}
	}
	return sb.String()
}
