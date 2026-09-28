module github.com/securosys-com/securosys-hsm-autounseal

go 1.27.0

replace github.com/openbao/go-kms-wrapping/kms/securosyshsm/v2 => github.com/openbao/go-kms-wrapping/kms/securosyshsm/v2 v2.0.0-20260923195439-ecc01122e406

require (
	github.com/openbao/go-kms-wrapping/kms/securosyshsm/v2 v2.0.0
	github.com/openbao/go-kms-wrapping/plugin/v2 v2.4.0
	github.com/openbao/go-kms-wrapping/v2 v2.9.0
	github.com/openbao/go-kms-wrapping/wrappers/securosyshsm/v2 v2.0.0-20260923195439-ecc01122e406
)

require (
	github.com/fatih/color v1.18.0 // indirect
	github.com/go-viper/mapstructure/v2 v2.5.0 // indirect
	github.com/golang/protobuf v1.5.4 // indirect
	github.com/hashicorp/go-hclog v1.6.3 // indirect
	github.com/hashicorp/go-plugin v1.7.0 // indirect
	github.com/hashicorp/go-secure-stdlib/parseutil v0.2.0 // indirect
	github.com/hashicorp/go-secure-stdlib/strutil v0.1.2 // indirect
	github.com/hashicorp/go-sockaddr v1.0.7 // indirect
	github.com/hashicorp/go-uuid v1.0.3 // indirect
	github.com/hashicorp/yamux v0.1.2 // indirect
	github.com/mattn/go-colorable v0.1.14 // indirect
	github.com/mattn/go-isatty v0.0.20 // indirect
	github.com/mitchellh/mapstructure v1.5.0 // indirect
	github.com/oklog/run v1.2.0 // indirect
	github.com/ryanuber/go-glob v1.0.0 // indirect
	github.com/securosys-com/tsb-client-go v1.3.0 // indirect
	golang.org/x/net v0.49.0 // indirect
	golang.org/x/sys v0.40.0 // indirect
	golang.org/x/text v0.33.0 // indirect
	google.golang.org/genproto/googleapis/rpc v0.0.0-20251222181119-0a764e51fe1b // indirect
	google.golang.org/grpc v1.78.0 // indirect
	google.golang.org/protobuf v1.36.11 // indirect
)
