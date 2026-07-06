# Securosys HSM Auto-Unseal Plugin for OpenBao

This project builds a standalone OpenBao KMS wrapper plugin for Securosys HSM
auto-unseal. The plugin connects OpenBao to Securosys Primus HSM or CloudsHSM
through the REST-based TSB interface and serves the `wrappers/securosyshsm`
wrapper through `github.com/openbao/go-kms-wrapping/plugin/v2`.

The integration lets OpenBao unlock its storage key with HSM-backed security
and supports Securosys approval workflows for compliance-oriented deployments.

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

Install Go before building the plugin.

The current `go.mod` uses local `replace` directives that point to the adjacent
`../securosys-go-kms-wrapping` checkout, so it builds against your
`feature/update-securosys-kms` wrapper branch.

OpenBao must include KMS auto-unseal plugin support. Use an OpenBao beta build
with KMS plugin support, such as
[OpenBao v2.6.0-beta20260622](https://github.com/openbao/openbao/releases/tag/v2.6.0-beta20260622),
to run this plugin. Stock OpenBao v2.5.4 rejects the `plugin "kms"` stanza
with:

```text
"kms" is not a supported plugin type
```

For local testing in this workspace, build OpenBao from the adjacent
`../securosys-openbao` checkout on `feature/using_securosyshsm_kms`.

## Known limitations

- OpenBao logs do not work yet with
  [OpenBao v2.6.0-beta20260622](https://github.com/openbao/openbao/releases/tag/v2.6.0-beta20260622).
  This is expected to be fixed in a newer OpenBao release.
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

Build the local OpenBao binary with KMS auto-unseal plugin support:

```sh
cd ../securosys-openbao
go build -o ../securosys-hsm-autounseal/bao-kms .
cd ../securosys-hsm-autounseal
```

## How to run OpenBao

### Auto-unseal with securosys-hsm

Auto-unseal is configured with two parts:

- A `plugin "kms" "securosys-hsm"` stanza that registers this external KMS
  plugin.
- A `seal "securosys-hsm"` stanza that configures the Securosys HSM connection.

The plugin must be registered in the server configuration because OpenBao has
to load the seal before storage is unsealed.

Example:

```hcl
plugin_directory = "./plugins"

plugin "kms" "securosys-hsm" {
  command   = "openbao-plugin-securosyshsm"
  sha256sum = "700721592418e7ecbea2020c9ec1727c7ef9fd07d58c72395cc95bd783eca4a7"
}

seal "securosys-hsm" {
  key_label        = "replace-me_key_label"
  key_password     = "replace-me_key_password"
  tsb_api_endpoint = "replace-me_tsb_api_endpoint"

  # Authorization type: TOKEN, CERT, or NONE.
  auth         = "TOKEN"
  bearer_token = "replace-me_bearer_token"

  # For certificate authentication, use:
  # auth      = "CERT"
  # cert_path = "replace-me_cert_path"
  # key_path  = "replace-me_key_path"

  # For unauthenticated test endpoints, use:
  # auth = "NONE"

  check_every      = 5
  approval_timeout = 600
}
```

Supported optional values include:

- `cert_path` and `key_path` for `CERT` authentication.
- `policy`, `full_policy`, and `full_policy_file` for approval policy data.
- `application_key_pair` for application-level signing keys.
- `api_keys` for token-style Securosys operation authorization.

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
- Creates an `admin` ACL policy.
- Creates an `admin` user with the `admin` policy.

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
  key_label        = "replace-me_key_label"
  key_password     = "replace-me_key_password"
  tsb_api_endpoint = "replace-me_tsb_api_endpoint"

  # Authorization type: TOKEN, CERT, or NONE.
  auth         = "TOKEN"
  bearer_token = "replace-me_bearer_token"
  # cert_path = "replace-me_cert_path"
  # key_path  = "replace-me_key_path"

  check_every      = 5
  approval_timeout = 600
}
```

### `config/selfinitialization.hcl`

```hcl
initialize "bootstrap" {
  request "enable-userpass" {
    operation = "update"
    path      = "sys/auth/userpass"

    data = {
      type = "userpass"
    }
  }

  request "create-admin-policy" {
    operation = "update"
    path      = "sys/policies/acl/admin"

    data = {
      policy = <<EOT
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOT
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

This project follows the license terms declared by the repository.
