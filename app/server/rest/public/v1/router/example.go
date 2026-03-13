package router

import (
	"github.com/evenyosua18/go-project-template/app/server/rest/public/v1/container"
	"github.com/evenyosua18/ego/http"
)

func RegisterExampleRoutes(r http.IHttpRouter) {
	// example container
	c := container.InitExample()

	// route
	r.Get("/example", c.Get)
}
