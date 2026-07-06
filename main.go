// Copyright (c) 2026 Securosys SA.
// SPDX-License-Identifier: MPL-2.0

package main

import (
	kmsplugin "github.com/openbao/go-kms-wrapping/plugin/v2"
	wrapping "github.com/openbao/go-kms-wrapping/v2"
	securosyshsm "github.com/openbao/go-kms-wrapping/wrappers/securosyshsm/v2"
)

func main() {
	kmsplugin.Serve(&kmsplugin.ServeOpts{
		WrapperFactoryFunc: func() wrapping.Wrapper {
			return securosyshsm.NewWrapper()
		},
	})
}
