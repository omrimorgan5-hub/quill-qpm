package manifest

import (
	"encoding/json"
	"fmt"
	"os"
)

type Manifest struct {
	Name    string            `json:"name"`
	Version string            `json:"version"`
	Main    string            `json:"main"`
	Deps    map[string]string `json:"deps"`
}

func Read(path string) (Manifest, error) {
	var m Manifest
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return Manifest{}, fmt.Errorf("no quill.json found — run 'qpm init' first")
		}
		return Manifest{}, err
	}
	if err := json.Unmarshal(data, &m); err != nil {
		return Manifest{}, fmt.Errorf("invalid quill.json: %w", err)
	}
	if m.Deps == nil {
		m.Deps = make(map[string]string)
	}
	return m, nil
}

func Write(path string, m Manifest) error {
	data, err := json.MarshalIndent(m, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, append(data, '\n'), 0644)
}
