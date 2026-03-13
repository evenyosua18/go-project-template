package public

import (
	"github.com/evenyosua18/go-project-template/app/server/rest/public/v1/router"
	"github.com/evenyosua18/ego/http"
)

const (
	RoutePublic = "public"
)

func RegisterPublicRoutes() {
	http.RegisterRouteByGroup(RoutePublic, []http.RouteFunc{
		router.RegisterExampleRoutes,
	})
}
