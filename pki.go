package main

import (
	"bytes"
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"fmt"
	"io/ioutil"
	"log"
	"math/big"
	mrand "math/rand"
	"net"
	"os"
	"path"
	"time"

	"golang.org/x/crypto/ssh"
)

const (
	ValidityDuration = time.Hour * 24 * 365 * 2
	PkiKeySize       = 4096
	SshKeySize       = 4096
)

type PkiKeyCertPair struct {
	CertificatePem string
	PrivateKeyPem  string
}

func SaveDeploymentFile(directory, filename, contents string, filemode os.FileMode) error {
	return ioutil.WriteFile(
		path.Join(directory, filename),
		[]byte(contents),
		filemode)
}

func CreateSaveSsh(username, outputDirectory string) (privateKey *rsa.PrivateKey, publicKeyString string, err error) {
	privateKey, publicKeyString, err = CreateSsh()
	if err != nil {
		return nil, "", err
	}

	privateKeyPem := PrivateKeyToPem(privateKey)
	err = SaveDeploymentFile(outputDirectory, fmt.Sprintf("%s_rsa", username), string(privateKeyPem), 0600)
	if err != nil {
		return nil, "", err
	}
	err = SaveDeploymentFile(outputDirectory, fmt.Sprintf("%s_rsa.pub", username), string(publicKeyString), 0600)
	if err != nil {
		return nil, "", err
	}
	return privateKey, publicKeyString, nil
}

func CreateSsh() (privateKey *rsa.PrivateKey, publicKeyString string, err error) {
	log.Print("ssh: generating ", SshKeySize, "bit rsa key", SshKeySize)

	privateKey, err = rsa.GenerateKey(rand.Reader, SshKeySize)
	if err != nil {
		return nil, "", fmt.Errorf("failed to generate private key for ssh: %q", err)
	}

	publicKey := privateKey.PublicKey
	sshPublicKey, err := ssh.NewPublicKey(&publicKey)
	if err != nil {
		return nil, "", fmt.Errorf("failed to create openssh public key string: %q", err)
	}
	authorizedKeyBytes := ssh.MarshalAuthorizedKey(sshPublicKey)
	authorizedKey := string(authorizedKeyBytes)

	return privateKey, authorizedKey, nil
}

func CreateSavePki(masterFQDN string, extraFQDNs []string, clusterDomain string, extraIPs []net.IP, outputDirectory string) (*PkiKeyCertPair, *PkiKeyCertPair, *PkiKeyCertPair, error) {
	ca, apiserver, client, err := CreatePki(masterFQDN, extraFQDNs, extraIPs, clusterDomain)
	if err != nil {
		return nil, nil, nil, err
	}

	err = SaveDeploymentFile(outputDirectory, "ca.key", (*ca).PrivateKeyPem, 0600)
	if err != nil {
		return nil, nil, nil, err
	}
	err = SaveDeploymentFile(outputDirectory, "ca.crt", (*ca).CertificatePem, 0600)
	if err != nil {
		return nil, nil, nil, err
	}
	err = SaveDeploymentFile(outputDirectory, "apiserver.key", (*apiserver).PrivateKeyPem, 0600)
	if err != nil {
		return nil, nil, nil, err
	}
	err = SaveDeploymentFile(outputDirectory, "apiserver.crt", (*apiserver).CertificatePem, 0600)
	if err != nil {
		return nil, nil, nil, err
	}
	err = SaveDeploymentFile(outputDirectory, "client.key", (*client).PrivateKeyPem, 0600)
	if err != nil {
		return nil, nil, nil, err
	}
	err = SaveDeploymentFile(outputDirectory, "client.crt", (*client).CertificatePem, 0600)
	if err != nil {
		return nil, nil, nil, err
	}

	return ca, apiserver, client, nil
}

func CreatePki(masterFQDN string, extraFQDNs []string, extraIPs []net.IP, clusterDomain string) (*PkiKeyCertPair, *PkiKeyCertPair, *PkiKeyCertPair, error) {
	extraFQDNs = append(extraFQDNs, fmt.Sprintf("kubernetes"))
	extraFQDNs = append(extraFQDNs, fmt.Sprintf("kubernetes.default"))
	extraFQDNs = append(extraFQDNs, fmt.Sprintf("kubernetes.default.svc"))
	extraFQDNs = append(extraFQDNs, fmt.Sprintf("kubernetes.default.svc.%s", clusterDomain))
	extraFQDNs = append(extraFQDNs, fmt.Sprintf("kubernetes.kube-system"))
	extraFQDNs = append(extraFQDNs, fmt.Sprintf("kubernetes.kube-system.svc"))
	extraFQDNs = append(extraFQDNs, fmt.Sprintf("kubernetes.kube-system.svc.%s", clusterDomain))

	log.Print("pki: generating certificate authority")
	caCertificate, caPrivateKey, err := createCertificate("KubernetesAzure", nil, nil, false, "", nil, nil)
	if err != nil {
		return nil, nil, nil, err
	}
	log.Print("pki: generating apiserver server certificate")
	apiserverCertificate, apiserverPrivateKey, err := createCertificate("apiserver", caCertificate, caPrivateKey, true, masterFQDN, extraFQDNs, extraIPs)
	if err != nil {
		return nil, nil, nil, err
	}
	log.Print("pki: generating client certificate")
	clientCertificate, clientPrivateKey, err := createCertificate("client", caCertificate, caPrivateKey, false, "", nil, nil)
	if err != nil {
		return nil, nil, nil, err
	}

	return &PkiKeyCertPair{CertificatePem: string(CertificateToPem(caCertificate.Raw)), PrivateKeyPem: string(PrivateKeyToPem(caPrivateKey))},
		&PkiKeyCertPair{CertificatePem: string(CertificateToPem(apiserverCertificate.Raw)), PrivateKeyPem: string(PrivateKeyToPem(apiserverPrivateKey))},
		&PkiKeyCertPair{CertificatePem: string(CertificateToPem(clientCertificate.Raw)), PrivateKeyPem: string(PrivateKeyToPem(clientPrivateKey))}, nil
}

func createCertificate(commonName string, caCertificate *x509.Certificate, caPrivateKey *rsa.PrivateKey, isServer bool, FQDN string, extraFQDNs []string, extraIPs []net.IP) (*x509.Certificate, *rsa.PrivateKey, error) {
	var err error

	isCA := (caCertificate == nil)

	now := time.Now()

	template := x509.Certificate{
		Subject:   pkix.Name{CommonName: commonName},
		NotBefore: now,
		NotAfter:  now.Add(ValidityDuration),

		KeyUsage:              x509.KeyUsageKeyEncipherment | x509.KeyUsageDigitalSignature,
		BasicConstraintsValid: true,
	}

	if isCA {
		template.KeyUsage |= x509.KeyUsageCertSign
		template.IsCA = isCA
	} else if isServer {
		extraFQDNs = append(extraFQDNs, FQDN)
		extraIPs = append(extraIPs, net.ParseIP("10.3.0.1"))

		template.DNSNames = extraFQDNs
		template.IPAddresses = extraIPs
		template.ExtKeyUsage = append(template.ExtKeyUsage, x509.ExtKeyUsageServerAuth)
	} else {
		template.ExtKeyUsage = append(template.ExtKeyUsage, x509.ExtKeyUsageClientAuth)
	}

	snMax := new(big.Int).Lsh(big.NewInt(1), 128)
	template.SerialNumber, err = rand.Int(rand.Reader, snMax)
	if err != nil {
		return nil, nil, err
	}

	privateKey, err := rsa.GenerateKey(rand.Reader, PkiKeySize)

	var privateKeyToUse *rsa.PrivateKey
	var certificateToUse *x509.Certificate
	if !isCA {
		privateKeyToUse = caPrivateKey
		certificateToUse = caCertificate
	} else {
		privateKeyToUse = privateKey
		certificateToUse = &template
	}

	certDerBytes, err := x509.CreateCertificate(rand.Reader, &template, certificateToUse, &privateKey.PublicKey, privateKeyToUse)
	if err != nil {
		return nil, nil, err
	}

	certificate, err := x509.ParseCertificate(certDerBytes)
	if err != nil {
		return nil, nil, err
	}

	return certificate, privateKey, nil
}

func PemToCertificate(pemString string) (*x509.Certificate, error) {
	pemBytes := []byte(pemString)
	pemBlock, _ := pem.Decode(pemBytes)

	certificate, err := x509.ParseCertificate(pemBlock.Bytes)
	if err != nil {
		return nil, err
	}

	return certificate, err
}

func PemToPrivateKey(pemString string) (*rsa.PrivateKey, error) {
	pemBytes := []byte(pemString)
	pemBlock, _ := pem.Decode(pemBytes)

	privateKey, err := x509.ParsePKCS1PrivateKey(pemBlock.Bytes)
	if err != nil {
		return nil, err
	}

	return privateKey, err
}

func CertificateToPem(derBytes []byte) []byte {
	pemBlock := &pem.Block{
		Type:  "CERTIFICATE",
		Bytes: derBytes,
	}
	pemBuffer := bytes.Buffer{}
	pem.Encode(&pemBuffer, pemBlock)

	return pemBuffer.Bytes()
}

func PrivateKeyToPem(privateKey *rsa.PrivateKey) []byte {
	pemBlock := &pem.Block{
		Type:  "RSA PRIVATE KEY",
		Bytes: x509.MarshalPKCS1PrivateKey(privateKey),
	}
	pemBuffer := bytes.Buffer{}
	pem.Encode(&pemBuffer, pemBlock)

	return pemBuffer.Bytes()
}

func RandStringBytes(n int) string {
	mrand.Seed(time.Now().UTC().UnixNano())
	letterBytes := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	littleBytes := "abcdefghijklmnopqrstuvwxyz"
	bigBytes := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	digitBytes := "0123456789"
	otherBytes := "$!%"

	b := make([]byte, n-4)
	for i := range b {
		b[i] = letterBytes[mrand.Intn(len(letterBytes))]
	}
	b = append(b, littleBytes[mrand.Intn(len(littleBytes))])
	b = append(b, bigBytes[mrand.Intn(len(bigBytes))])
	b = append(b, digitBytes[mrand.Intn(len(digitBytes))])
	b = append(b, otherBytes[mrand.Intn(len(otherBytes))])

	dest := make([]byte, len(b))
	perm := mrand.Perm(len(b))
	for i, v := range perm {
		dest[v] = b[i]
	}
	return string(dest)
}

func main() {
	masterFqdn := os.Getenv("MASTER_FQDN")
	extraFqdn := os.Getenv("MASTER_EXTRA_FQDN")
	clusterDomain := os.Getenv("CLUSTER_DOMAIN")
	masterPrivateIP := os.Getenv("MASTER_PRIVATE_IP")
	userName := os.Getenv("ADMIN_USER_NAME")
	secretPath := os.Getenv("SECRET_PATH")

	mpip := net.ParseIP(masterPrivateIP)

	pass := RandStringBytes(18)
	SaveDeploymentFile(secretPath, "admin_password", pass, 0600)

	_, _, err := CreateSaveSsh(userName, secretPath)
	if err != nil {
		log.Fatalf("Error occurred while creating SSH assets.")
	}

	_, _, _, err = CreateSavePki(masterFqdn, []string{extraFqdn}, clusterDomain, []net.IP{mpip}, secretPath)
	if err != nil {
		log.Fatalf("Error occurred while creating PKI assets.")
	}
}
