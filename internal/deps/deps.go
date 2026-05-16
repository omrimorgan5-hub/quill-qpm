package deps

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

type DepSpec struct {
	Host string
	User string
	Repo string
	Ref  string
}

func (d DepSpec) FullName() string {
	return d.User + "/" + d.Repo
}

func (d DepSpec) String() string {
	ref := d.Ref
	if ref == "" {
		ref = "latest"
	}
	return fmt.Sprintf("%s:%s/%s#%s", d.Host, d.User, d.Repo, ref)
}

func ParseSpec(s string) (DepSpec, error) {
	s = strings.TrimSpace(s)

	// Full form: github:user/repo#ref
	if strings.Contains(s, ":") {
		parts := strings.SplitN(s, ":", 2)
		host := parts[0]
		rest := parts[1]
		return parseRepoRef(host, rest)
	}

	// Short form: user/repo or user/repo#ref
	return parseRepoRef("github", s)
}

func parseRepoRef(host, rest string) (DepSpec, error) {
	var ref string
	if idx := strings.Index(rest, "#"); idx != -1 {
		ref = rest[idx+1:]
		rest = rest[:idx]
	}

	parts := strings.Split(rest, "/")
	if len(parts) != 2 {
		return DepSpec{}, fmt.Errorf("invalid repo format: %s", rest)
	}

	return DepSpec{
		Host: host,
		User: parts[0],
		Repo: parts[1],
		Ref:  ref,
	}, nil
}

func Install(dep DepSpec, modulesDir string) error {
	dest := filepath.Join(modulesDir, dep.User, dep.Repo)

	if _, err := os.Stat(dest); err == nil {
		return fmt.Errorf("%s already exists — run 'qpm update' instead", dep.FullName())
	}

	url := fmt.Sprintf("https://%s.com/%s/%s.git", dep.Host, dep.User, dep.Repo)

	if err := os.MkdirAll(dest, 0755); err != nil {
		return err
	}

	cmd := exec.Command("git", "clone", "--depth", "1", url, dest)
	if dep.Ref != "" {
		cmd = exec.Command("git", "clone", "--depth", "1", "--branch", dep.Ref, url, dest)
	}
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		os.RemoveAll(dest)
		return fmt.Errorf("git clone failed: %w", err)
	}

	// Install transitive deps
	manifestPath := filepath.Join(dest, "quill.json")
	if data, err := os.ReadFile(manifestPath); err == nil {
		var m struct {
			Deps map[string]string `json:"deps"`
		}
		if err := json.Unmarshal(data, &m); err == nil && m.Deps != nil {
			for _, raw := range m.Deps {
				transitive, err := ParseSpec(raw)
				if err != nil {
					continue
				}
				if _, err := os.Stat(filepath.Join(modulesDir, transitive.User, transitive.Repo)); os.IsNotExist(err) {
					if err := Install(transitive, modulesDir); err != nil {
						fmt.Fprintf(os.Stderr, "warning: failed to install transitive dep %s: %v\n", transitive.FullName(), err)
					}
				}
			}
		}
	}

	return nil
}

func Update(dep DepSpec, modulesDir string) error {
	dest := filepath.Join(modulesDir, dep.User, dep.Repo)

	if _, err := os.Stat(dest); os.IsNotExist(err) {
		return Install(dep, modulesDir)
	}

	cmd := exec.Command("git", "-C", dest, "pull", "--ff-only")
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("git pull failed: %w", err)
	}

	if dep.Ref != "" {
		cmd = exec.Command("git", "-C", dest, "checkout", dep.Ref)
		cmd.Stderr = os.Stderr
		if err := cmd.Run(); err != nil {
			return fmt.Errorf("checkout failed: %w", err)
		}
	}

	return nil
}
