# Mosquitto MQTT Broker on OpenShift

A containerized deployment solution for the Eclipse Mosquitto MQTT message broker on Red Hat OpenShift. This repository provides Docker images, OpenShift manifests, and deployment procedures for running a secure, production-ready MQTT broker in an OpenShift environment.

## Features

- 🐳 **Lightweight Container**: Alpine Linux-based image (~7MB)
- 🔐 **Security-First**: TLS encryption and user authentication
- ☸️ **OpenShift Ready**: Compatible with OpenShift 3.11+ and 4.x
- 📁 **Organized Structure**: Clean separation of configs, certificates, and scripts
- 🚀 **Easy Deployment**: One-command deployment with OpenShift manifests


Clone or fork the project from github: [mosquitto-openshift](https://github.com/deepak-madhukar/mosquitto-openshift.git)

```bash
git clone <repo_url>
```

## Project Structure

```
├── auth/          # Authentication files (user credentials)
├── certs/         # SSL/TLS certificates (CA, server cert/key)
├── config/        # Mosquitto configuration files
├── openshift/     # OpenShift deployment manifests
└── scripts/       # Container startup and utility scripts
```

## Prerequisites

- OpenShift cluster (3.11+ or 4.x) or Kubernetes cluster
- `oc` CLI tool or `kubectl`
- Container runtime (`podman`, `docker`, or `buildah`) for building images
- Mosquitto client tools for testing (optional but recommended)


## About Mosquitto

[Eclipse Mosquitto](https://mosquitto.org/) is an open-source MQTT message broker that implements the MQTT protocol versions 5.0, 3.1.1, and 3.1. It's designed to be lightweight and is suitable for use on all devices from low-power single-board computers to full servers.

### Key Features
- **MQTT Standards Compliant**: Full support for MQTT 3.1, 3.1.1, and 5.0
- **Lightweight**: Minimal resource footprint
- **Cross-Platform**: Runs on Linux, Windows, macOS
- **Security**: Built-in authentication and TLS/SSL support
- **Bridge Support**: Can bridge to other MQTT brokers

This deployment includes TLS encryption support, which is required for external access through the OpenShift router.


## Architecture & Design Decisions

### Single Instance Deployment
Mosquitto does not natively support clustering, making it suitable for single-pod deployments. For high availability, consider using OpenShift's built-in pod restart capabilities and persistent volumes for message retention.

### Dual Listener Configuration
This deployment configures two MQTT listeners:
- **Internal (Port 1883)**: Plaintext MQTT for intra-cluster communication
- **External (Port 8883)**: TLS-encrypted MQTT for secure external access via OpenShift routes

> **Note**: The OpenShift router requires TLS encryption to properly route MQTT traffic, hence the necessity of the encrypted listener.

## Container Image

### Base Image & Size
The Docker image uses **Alpine Linux 3.11** as the base image, resulting in a minimal container (~7MB). While newer Alpine versions are available, 3.11 provides the most stable Mosquitto package for this deployment.

### Security Components
The container includes the following security elements:

| Component | Purpose | Default Value | Customizable |
|-----------|---------|---------------|--------------|
| **User Authentication** | Secure broker access | `admin:admin` | ✅ Yes |
| **TLS Certificates** | Encrypted communications | Self-signed test certs | ✅ Yes |
| **Configuration** | Broker settings & listeners | Dual-listener setup | ✅ Yes |
| **Startup Script** | Container initialization | Basic startup | ✅ Yes |

> **⚠️ Security Notice**: The default credentials (`admin:admin`) and self-signed certificates are for testing only. Replace them with production-grade secrets before deploying to production environments.

### File Organization
All custom files are organized by function and copied to `/myuser/` in the container:
- Configuration files maintain their structure for easy ConfigMap/Secret mounting
- Separation enables selective file replacement without rebuilding images

### User Authentication

Mosquitto supports multiple authentication methods. This deployment uses **password-based authentication** for simplicity, though client certificate authentication is also supported.

#### Creating Custom User Credentials

The password file uses Mosquitto's proprietary format. Use the `mosquitto_passwd` utility to manage users:

```bash
# Remove existing credentials
rm auth/passwd

# Create new user with password
mosquitto_passwd -c auth/passwd <username> <password>

# Add additional users (omit -c flag)
mosquitto_passwd auth/passwd <another_user> <another_password>
```

#### Multiple Users & Privileges
For advanced setups with user-specific permissions, you'll need to:
1. Add users to the password file (as shown above)
2. Configure access control lists (ACLs) in the main configuration file
3. Define topic-based permissions per user

### TLS Certificates

A secure MQTT deployment requires a complete certificate chain in **PEM format**:

| Certificate | File | Purpose |
|-------------|------|---------|
| **Root CA** | `ca.crt` | Certificate Authority for validation |
| **Server Certificate** | `server.crt` | Broker's public certificate |
| **Private Key** | `server.key` | Broker's private key |

> **💡 Production Tip**: While this example includes self-signed certificates for testing, production deployments should use certificates from a trusted CA or your organization's PKI infrastructure.

#### Generating Custom Certificates

The following OpenSSL commands generate a complete certificate chain for testing:

    $ openssl req -new -x509 -days 3650 -extensions v3_ca -keyout certs/ca.key -out certs/ca.crt -subj "/O=acme/CN=com"

    $ openssl genrsa -out certs/server.key 2048

    $ openssl req -new -out certs/server.csr -key  certs/server.key -subj "/O=acme2/CN=com"

    $ openssl x509 -req -in certs/server.csr -CA certs/ca.crt -CAkey certs/ca.key -CAcreateserial -out certs/server.crt -days 3650

    $ openssl rsa -in certs/server.key -out certs/server.key

    $ rm certs/ca.key certs/ca.srl certs/server.csr

    $ chmod 644 certs/server.key

### Configuration File

The `mosquitto.conf` file defines:
- **Listener Configuration**: Ports 1883 (plaintext) and 8883 (TLS)
- **Certificate Paths**: References to TLS certificate files
- **Authentication**: Password file location and settings

## 🔨 Building the Container Image

Build the container image using your preferred container runtime:

```bash
# Using Podman (recommended for OpenShift)
podman build -t mosquitto-openshift:latest .

# Using Docker
docker build -t mosquitto-openshift:latest .

# Using Buildah
buildah build-using-dockerfile -t mosquitto-openshift:latest .
```

## 🧪 Local Testing

Before deploying to OpenShift, test the container locally to ensure everything works correctly.

> **🔑 Authentication Note**: All commands below use `<username>` and `<password>` placeholders. Replace these with:
> - **Default credentials**: `admin` / `admin` (included in this repository)
> - **Custom credentials**: Your configured username/password if you've modified the auth file

### 1. Run the Container

```bash
# Get the image ID
podman images

# Run with port forwarding
podman run -d --name mosquitto-test \
  -p 1883:1883 \
  -p 8883:8883 \
  mosquitto-openshift:latest
```

### 2. Test Plaintext Connection

> **Credentials**: 
> - **Default**: `admin/admin` (if using the included password file)
> - **Custom**: Use your configured username/password if you've modified the auth file

```bash
# Publish a test message
mosquitto_pub -h localhost -p 1883 -t test/topic -m "Hello MQTT" -u <username> -P <password>

# Subscribe to messages (in another terminal)
mosquitto_sub -h localhost -p 1883 -t test/topic -u <username> -P <password>
```

> **💡 Example**: Replace `<username>` with `admin` and `<password>` with `admin` if using default credentials

### 3. Test TLS Connection

```bash
# Publish via TLS
mosquitto_pub -h localhost -p 8883 -t test/secure -m "Hello Secure MQTT" \
  --cafile certs/ca.crt --insecure -u <username> -P <password>

# Subscribe via TLS
mosquitto_sub -h localhost -p 8883 -t test/secure \
  --cafile certs/ca.crt --insecure -u <username> -P <password>
```

> **Note**: The `--insecure` flag bypasses hostname verification since the test certificate uses `acme.com` as the hostname. 

## 📦 Publishing the Image

After successful local testing, publish the image to a container registry accessible by your OpenShift cluster.

### Using Red Hat Quay

```bash
# Tag the image
podman tag mosquitto-openshift:latest quay.io/<username>/mosquitto-openshift:latest

# Login to Quay
podman login quay.io

# Push the image
podman push quay.io/<username>/mosquitto-openshift:latest
```

### Using Docker Hub

```bash
# Tag the image
podman tag mosquitto-openshift:latest docker.io/<username>/mosquitto-openshift:latest

# Login to Docker Hub
podman login docker.io

# Push the image
podman push docker.io/<username>/mosquitto-openshift:latest
```

### Using OpenShift Internal Registry

```bash
# Tag for internal registry
podman tag mosquitto-openshift:latest default-route-openshift-image-registry.apps.<cluster>/myproject/mosquitto-openshift:latest

# Push to internal registry
podman push default-route-openshift-image-registry.apps.<cluster>/myproject/mosquitto-openshift:latest
```

> **📝 Note**: Update the image reference in your OpenShift manifests to match your chosen registry and tag.

## 🚀 OpenShift Deployment

Deploy Mosquitto to your OpenShift cluster using the provided OpenShift manifests. These configurations work with OpenShift 3.11+ and 4.x.

### Quick Start Deployment

1. **Select Your Project**
   ```bash
   # List available projects
   oc get projects
   
   # Create a new project (optional)
   oc new-project mosquitto-mqtt
   
   # Switch to your target project
   oc project <your-project-name>
   ```

2. **Deploy with Default Configuration**
   ```bash
   oc apply -f openshift/mosquitto-ephemeral.yaml
   ```

This creates:
- **Deployment**: Single-replica Mosquitto pod
- **Services**: Internal (1883) and external (8883) MQTT listeners  
- **Default Security**: Admin user with test certificates

### 🌐 External Access Configuration

Enable external access to your MQTT broker through OpenShift routes.

1. **Create a Passthrough Route**
   ```bash
   # Create route with auto-assigned hostname
   oc create route passthrough --service=mosquitto-ephemeral-tls --port 8883
   
   # Get the assigned hostname
   oc get route
   ```

2. **Get CA Certificate for Client Connections**
   ```bash
   # Method 1: Use the local certificate, present in certs folder
   
   # Method 2: Extract from running pod
   oc cp $(oc get pods -l app=mosquitto-ephemeral -o name):/myuser/certs/ca.crt certs/ca.crt
   ```

3. **Test External Connection**
   ```bash

   # Replace <route-hostname> with the hostname from 'oc get route'
   # Replace <username> and <password> with your credentials (default: admin/admin)

   # Subscribe
   mosquitto_sub -t external/test \
     --cafile certs/ca.crt --insecure \
     -u <username> -P <password> \
     -h <route-hostname> -p 443

   # Publish
   mosquitto_pub -t external/test -m "Hello from outside!" \
     --cafile certs/ca.crt --insecure \
     -u <username> -P <password> \
     -h <route-hostname> -p 443
   ```

> **🔍 Port Mapping**: External clients connect to port **443** (OpenShift router's TLS port), not the pod's internal port 8883. 

### 🔧 Custom Configuration Deployment

Override default configurations using OpenShift ConfigMaps and Secrets for production deployments.

#### Example: Custom User Credentials

1. **Create Custom Password File**
   ```bash
   # Create new credentials file
   touch custom_passwd
   mosquitto_passwd -c custom_passwd production_user secure_password_123
   
   # Add additional users
   mosquitto_passwd custom_passwd readonly_user readonly_pass
   ```

2. **Create ConfigMap**
   ```bash
   oc create configmap mosquitto-passwd --from-file=passwd=./custom_passwd
   ```

3. **Deploy with Custom Configuration**
   ```bash
   # Ensure you're in the correct project
   oc project <your-project-name>
   
   # Deploy with custom credentials
   oc apply -f openshift/mosquitto-ephemeral-passwd.yaml
   ```

#### Volume Mount Configuration
The custom deployment YAML (`mosquitto-ephemeral-passwd.yaml`) includes:
```yaml
spec:
  containers:
    volumeMounts:
      - name: passwd-mount
        mountPath: /myuser/passwd
        subPath: passwd
  volumes:
    - name: passwd-mount
      configMap:
        name: mosquitto-passwd
```

4. **Verify Custom Credentials**
   ```bash
   # Test with new credentials
   mosquitto_pub -t test/auth -m "Custom auth test" \
     -u production_user -P secure_password_123 \
     -h <route-hostname> -p 443 --cafile certs/ca.crt --insecure
   ```

## 🔮 Advanced Configurations

### Custom Certificates
Replace test certificates with production ones using the same ConfigMap approach:
```bash
# Create certificate ConfigMaps
oc create configmap mosquitto-certs \
  --from-file=ca.crt=./production-ca.crt \
  --from-file=server.crt=./production-server.crt \
  --from-file=server.key=./production-server.key

# Create Secret for sensitive key material (recommended)
oc create secret generic mosquitto-tls \
  --from-file=server.key=./production-server.key
```

### Configuration Management Strategies

| Approach | Use Case | Pros | Cons |
|----------|----------|------|------|
| **ConfigMaps** | Non-sensitive config files | Easy to manage, version control | Visible in cluster |
| **Secrets** | Certificates, passwords | Encrypted at rest | More complex setup |
| **Environment Variables** | Simple key-value configs | Built into YAML | Limited to simple values |
| **Init Containers** | Complex config generation | Maximum flexibility | Increased complexity |

### Production Considerations

- **Persistent Storage**: Add PVCs for message persistence and log retention
- **Resource Limits**: Set CPU/Memory limits based on expected load
- **Health Checks**: Configure liveness/readiness probes for reliability  
- **Monitoring**: Integrate with Prometheus for metrics collection
- **Backup Strategy**: Plan for configuration and persistent data backup

### Operator Alternative
While operators could manage Mosquitto deployments, the simplicity of this single-pod deployment makes traditional YAML manifests more practical and easier to understand. 

## 📚 Additional Resources

- **[Eclipse Mosquitto Documentation](https://mosquitto.org/documentation/)**
- **[MQTT Protocol Specification](https://mqtt.org/)**
- **[OpenShift Container Platform Documentation](https://docs.openshift.com/)**
- **[Kubernetes ConfigMaps and Secrets](https://kubernetes.io/docs/concepts/configuration/)**

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests to improve this deployment solution.

## 📄 License

This project follows the same license terms as the original Eclipse Mosquitto project.

## 👏 Credits

This project is based on the foundational work by **Kevin Boone**. For detailed technical discussion and background, see the original article:

**[Mosquitto on OpenShift - Kevin Boone](http://kevinboone.me/mosquitto-openshift.html)**

---
Compiled with ☕, tested on luck
