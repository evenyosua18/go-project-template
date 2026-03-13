//go:build wireinject
// +build wireinject

package container

import (
	dbExample "github.com/evenyosua18/go-project-template/app/repository/db/example"
	apiExample "github.com/evenyosua18/go-project-template/app/server/rest/public/v1/api/example"
	"github.com/evenyosua18/go-project-template/app/usecase/example"
	"github.com/google/wire"
)

func InitExample() *apiExample.ApiExample {
	wire.Build(
		dbExample.NewExampleRepository,
		example.NewExampleUsecase,
		apiExample.NewExampleApi,
	)

	return nil
}
