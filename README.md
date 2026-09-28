# Securosys HSM Auto-Unseal Plugin for OpenBao

This project builds a standalone OpenBao KMS plugin for Securosys HSM
auto-unseal and External Keys. The plugin connects OpenBao to Securosys Primus
HSM or CloudsHSM through the REST-based TSB interface and serves both the
`wrappers/securosyshsm` wrapper and the `kms/securosyshsm` implementation
through `github.com/openbao/go-kms-wrapping/plugin/v2`.

The integration lets OpenBao unlock its storage key with HSM-backed security.

## Table of Contents

- [Glossary](#glossary)
- [Setup](#setup)
- [Known limitations](#known-limitations)
- [Build](#build)
- [How to run OpenBao](#how-to-run-openbao)
  - [Auto-unseal with securosys-hsm](#auto-unseal-with-securosys-hsm)
  - [Self-initialization with HCL files](#self-initialization-with-hcl-files)
- [Examples with three HCL files](#examples-with-three-hcl-files)
- [Getting Support](#getting-support)
- [License](#license)

## Glossary

| Term      | Description                                                                 |
| :-------- | :-------------------------------------------------------------------------- |
| CloudsHSM | HSM as a service, operated by Securosys                                     |
| HSM       | Hardware Security Module                                                    |
| JWT       | JSON Web Token, used for bearer-token authorization                         |
| TSB       | Transaction Security Broker, providing the REST interface to Securosys HSMs |
| UI        | OpenBao user interface                                                      |

## Setup

Install Go 1.27 or newer before building the plugin.

The project uses the official `github.com/openbao/go-kms-wrapping` modules.
Securosys wrapper and KMS support is included upstream.

Use [OpenBao v2.7.0](https://github.com/openbao/openbao/releases/tag/v2.7.0)
or newer to run this plugin. Older OpenBao versions without KMS plugin support
reject the `plugin "kms"` stanza with:

```text
"kms" is not a supported plugin type
```

## Known limitations

- This plugin currently supports non-SKA keys. SKA key support is expected to be fixed in a future OpenBao release.

## Build

Build the standalone KMS plugin:

```sh
go mod tidy
go build -o openbao-plugin-securosyshsm .
```

Calculate the SHA-256 checksum of the built plugin binary:

```sh
sha256sum openbao-plugin-securosyshsm
```

On macOS, use:

```sh
shasum -a 256 openbao-plugin-securosyshsm
```

Install the plugin into the directory configured by `plugin_directory` and
verify the installed binary checksum:

```sh
mkdir -p ./plugins
install -m 0755 openbao-plugin-securosyshsm ./plugins/openbao-plugin-securosyshsm
sha256sum ./plugins/openbao-plugin-securosyshsm
```

Optionally, build OpenBao 2.7.0 from an adjacent source checkout:

```sh
cd ../openbao
git checkout v2.7.0
go build -o ../securosys-openbao-autounseal-plugin/bao-kms .
cd ../securosys-openbao-autounseal-plugin
```

## How to run OpenBao

### Auto-unseal with securosys-hsm

Auto-unseal is configured with two parts:

- A `plugin "kms" "securosys-hsm"` stanza that registers this external KMS
  plugin.
- A `seal "securosys-hsm"` stanza that configures the Securosys HSM connection.

The plugin must be registered in the server configuration because OpenBao has
to load the seal before storage is unsealed.

The HSM key configured with `key_label` must already exist on the Securosys HSM
or CloudsHSM instance before OpenBao starts. Supported key types are RSA,
ML-KEM-512, ML-KEM-768, and ML-KEM-1024.

`health_check_enabled` must be set to **false** for the Securosys seal. OpenBao's
seal health check periodically performs encryption and decryption operations.
Enabling it can cause unnecessary HSM operations and may trigger approval
workflows for policy-protected keys.

Example:

```hcl
plugin_directory = "./plugins"

plugin "kms" "securosys-hsm" {
  command   = "openbao-plugin-securosyshsm"
  sha256sum = "ea516e46db1d7e10f8fe45b5199a7462163fcf10b4dee4d1500ae99ad574fddf"
}

seal "securosys-hsm" {
  # Required: disable OpenBao's periodic seal encryption/decryption health check.
  health_check_enabled = false

  # Existing HSM key. Supported types: RSA, ML-KEM-512, ML-KEM-768,
  # and ML-KEM-1024.
  key_label        = "replace-me_key_label"
  key_password     = "replace-me_key_password"
  tsb_api_endpoint = "replace-me_tsb_api_endpoint"

  # Authorization type: TOKEN, CERT, or NONE.
  auth         = "TOKEN"
  bearer_token = "bearer-token"

  # For certificate authentication, use:
  # auth      = "CERT"
  # cert_path = "/path/to/client.crt"
  # key_path  = "/path/to/client.key"

  # For unauthenticated test endpoints, use:
  # auth = "NONE"

  # Optional application key pair for metadata signatures.
  # Provide private_key and public_key without PEM headers.
  application_key_pair = "{\"private_key\":\"...\",\"public_key\":\"...\"}"

  # Optional TSB API keys. Multiple keys can be provided per token type.
  api_keys = "{\"key_management_token\":[\"key-management-api-key\"],\"key_operation_token\":[\"key-operation-api-key\"],\"service_token\":[\"service-api-key\"]}"

  check_every      = 5
  approval_timeout = 600
}
```

Supported optional values include:

- `cert_path` and `key_path` for `CERT` authentication.
- `application_key_pair` for metadata signatures. The value is a JSON string
  with `private_key` and `public_key`, without PEM headers.
- `api_keys` for TSB API-key authorization. The value is a JSON string. Common
  token arrays are `key_management_token`, `key_operation_token`, and
  `service_token`; approver flows can also use `approver_token` and
  `approver_key_management_token`.

Auto-unseal timeout settings:

| Parameter          | Example | Description                                                                |
| :----------------- | :------ | :------------------------------------------------------------------------- |
| `check_every`      | `5`     | How often OpenBao checks HSM approval status. Must be greater than `0`.    |
| `approval_timeout` | `600`   | Maximum time to wait for HSM approval. Must be greater than `check_every`. |

### Self-initialization with HCL files

Self-initialization lets OpenBao initialize itself on first startup and then run
declarative bootstrap requests from HCL. It requires auto-unseal, because there
is no Shamir key output to persist.

The example files are in `config/`:

- `config/config.hcl`: storage, listener, API address, and UI settings.
- `config/autounseal.hcl`: KMS plugin registration and `seal "securosys-hsm"`.
- `config/selfinitialization.hcl`: bootstrap requests executed after
  initialization.

Start OpenBao with the whole `config/` directory:

```sh
./bao-kms server -config=config
```

Alternatively, pass each file explicitly:

```sh
./bao-kms server \
  -config=config/config.hcl \
  -config=config/autounseal.hcl \
  -config=config/selfinitialization.hcl
```

The `initialize "bootstrap"` block in `config/selfinitialization.hcl` contains
ordered `request` blocks. The current example:

- Enables the `userpass` auth method.
- Creates an `admin` user.

Self-initialization runs only when the storage backend is not initialized yet.
On later starts, OpenBao skips the `initialize` block.

## Examples with three HCL files

Use three separate configuration files so base server settings, auto-unseal,
and bootstrap requests stay independent.

### `config/config.hcl`

```hcl
storage "raft" {
  path    = "./db"
  node_id = "raft_node_1"
}

listener "tcp" {
  address     = "127.0.0.1:8200"
  tls_disable = 1
}

api_addr     = "http://127.0.0.1:8200"
cluster_addr = "https://127.0.0.1:8201"
ui           = true
```

### `config/autounseal.hcl`

```hcl
plugin_directory = "./plugins"

plugin "kms" "securosys-hsm" {
  command   = "openbao-plugin-securosyshsm"
  sha256sum = "replace-me_sha256_filechecksum"
}

seal "securosys-hsm" {
  # Required: disable OpenBao's periodic seal encryption/decryption health check.
  health_check_enabled = false

  # Existing HSM key. Supported types: RSA, ML-KEM-512, ML-KEM-768,
  # and ML-KEM-1024.
  key_label        = "replace-me_key_label"
  key_password     = "replace-me_key_password"
  tsb_api_endpoint = "https://tsb.example.com"
  app_name         = "my-application"

  # Authorization type: TOKEN, CERT, or NONE.
  auth         = "TOKEN"
  bearer_token = "bearer-token"
  # cert_path = "/path/to/client.crt"
  # key_path  = "/path/to/client.key"
  # application_key_pair = "{\"private_key\":\"...\",\"public_key\":\"...\"}"
  # api_keys = "{\"key_management_token\":[\"key-management-api-key\"],\"key_operation_token\":[\"key-operation-api-key\"],\"service_token\":[\"service-api-key\"]}"

  check_every      = 5
  approval_timeout = 600
}
```

### `config/selfinitialization.hcl`

```hcl
initialize "bootstrap" {
  request "create-admin-policy" {
    operation = "update"
    path      = "sys/policies/acl/admin"

    data = {
      policy = <<-EOT
        path "*" {
          capabilities = ["create", "read", "update", "patch", "delete", "list", "scan", "sudo"]
        }
      EOT
    }
  }

  request "enable-userpass" {
    operation = "update"
    path      = "sys/auth/userpass"

    data = {
      type = "userpass"
    }
  }

  request "create-admin-user" {
    operation = "update"
    path      = "auth/userpass/users/admin"

    data = {
      password = "replace-me_admin_password"
      policies = ["admin"]
    }
  }
}
```

The checked-in local example uses `password = "root"` only for testing. Replace
it before using this configuration in any shared or persistent environment.

## Getting Support

For Securosys REST/TSB and HSM-related issues, Securosys customers with an
active support contract can open a support ticket through the Securosys Support
Portal.

For community feedback, report problems or suggested improvements in the
project issue tracker used for this repository.

## License

This project is licensed under the [Apache 2.0](./LICENSE) license.
