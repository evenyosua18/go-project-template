package cmd

import (
	"github.com/evenyosua18/ego/app"
	"github.com/spf13/cobra"
	"github.com/evenyosua18/go-project-template/app/server/rest/public"
	// _ "github.com/evenyosua18/go-project-template/app/server/rest/service" // register service routes here
)

func Execute() {
	// initiate cobra command
	rootCmd := &cobra.Command{
		Run: func(cmd *cobra.Command, args []string) {
			// register routes here before running the rest server
			public.RegisterPublicRoutes()
			// service.RegisterServiceRoutes()

			// run rest server
			app.GetApp().RunRest()
		},
	}

	// add commands here

	// execute all command
	if err := rootCmd.Execute(); err != nil {
		panic(err)
	}
}
