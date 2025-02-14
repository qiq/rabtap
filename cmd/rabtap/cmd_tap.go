// cmd_tap - the tap command
// Copyright (C) 2017-2021 Jan Delgado

package main

import (
	"context"
	"crypto/tls"
	"time"

	"golang.org/x/sync/errgroup"

	rabtap "github.com/jandelgado/rabtap/pkg"
)

type CmdTapArg struct {
	tapConfig          []rabtap.TapConfiguration
	tlsConfig          *tls.Config
	messageReceiveFunc MessageReceiveFunc
	termPred           Predicate
	filterPred         Predicate
	timeout            time.Duration
}

// cmdTap taps to the given exchanges and displays or saves the received
// messages.
// TODO feature: discover bindings when no binding keys are given (-> discovery.go)
func cmdTap(
	ctx context.Context,
	cmd CmdTapArg) {

	ctx, cancel := context.WithCancel(ctx)
	g, ctx := errgroup.WithContext(ctx)

	tapMessageChannel := make(rabtap.TapChannel)
	errorChannel := make(rabtap.SubscribeErrorChannel)

	for _, config := range cmd.tapConfig {
		config := config
		tap := rabtap.NewAmqpTap(config.AMQPURL, cmd.tlsConfig, log)
		g.Go(func() error {
			return tap.EstablishTap(ctx, config.Exchanges, tapMessageChannel, errorChannel)
		})
	}
	g.Go(func() error {
		acknowledger := createAcknowledgeFunc(false, false) // ACK
		err := messageReceiveLoop(ctx,
			tapMessageChannel,
			errorChannel,
			cmd.messageReceiveFunc,
			cmd.filterPred,
			cmd.termPred,
			acknowledger,
			cmd.timeout)
		cancel()
		return err
	})
	if err := g.Wait(); err != nil && err != ErrIdleTimeout {
		log.Errorf("tap failed with %v", err)
	}
}
