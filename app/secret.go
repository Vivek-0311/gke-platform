package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
)

const (
	metadataURL      = "http://metadata.google.internal/computeMetadata/v1"
	secretManagerURL = "https://secretmanager.googleapis.com/v1"
)

// fetchSecret reads the latest version of a Secret Manager secret.
// name is "projects/<project>/secrets/<secret>".
func fetchSecret(ctx context.Context, client *http.Client, metaURL, smURL, name string) (string, error) {
	token, err := metadataToken(ctx, client, metaURL)
	if err != nil {
		return "", fmt.Errorf("get token: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, smURL+"/"+name+"/versions/latest:access", nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("Authorization", "Bearer "+token)

	var body struct {
		Payload struct {
			Data string `json:"data"`
		} `json:"payload"`
	}
	if err := doJSON(client, req, &body); err != nil {
		return "", fmt.Errorf("access secret: %w", err)
	}

	value, err := base64.StdEncoding.DecodeString(body.Payload.Data)
	if err != nil {
		return "", fmt.Errorf("decode secret: %w", err)
	}
	return string(value), nil
}

// metadataToken asks the GKE metadata server for an access token of the
// Google service account bound to this pod's Kubernetes service account.
func metadataToken(ctx context.Context, client *http.Client, metaURL string) (string, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, metaURL+"/instance/service-accounts/default/token", nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("Metadata-Flavor", "Google")

	var body struct {
		AccessToken string `json:"access_token"`
	}
	if err := doJSON(client, req, &body); err != nil {
		return "", err
	}
	if body.AccessToken == "" {
		return "", fmt.Errorf("empty access token")
	}
	return body.AccessToken, nil
}

func doJSON(client *http.Client, req *http.Request, out any) error {
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		msg, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
		return fmt.Errorf("%s: %s", resp.Status, msg)
	}
	return json.NewDecoder(resp.Body).Decode(out)
}
