// SPDX-FileCopyrightText: Copyright 2026 Securosys SA
// SPDX-License-Identifier: Apache-2.0

package main

import (
	securosyshsmkms "github.com/openbao/go-kms-wrapping/kms/securosyshsm/v2"
	kmsplugin "github.com/openbao/go-kms-wrapping/plugin/v2"
	wrapping "github.com/openbao/go-kms-wrapping/v2"
	"github.com/openbao/go-kms-wrapping/v2/kms"
	securosyshsmwrapper "github.com/openbao/go-kms-wrapping/wrappers/securosyshsm/v2"
)

func main() {
	kmsplugin.Serve(&kmsplugin.ServeOpts{
		WrapperFactoryFunc: func() wrapping.Wrapper {
			return securosyshsmwrapper.NewWrapper()
		},
		KMSFactoryFunc: func() kms.KMS {
			return securosyshsmkms.New()
		},
	})
}
