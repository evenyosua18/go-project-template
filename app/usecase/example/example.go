package example

import (
	"context"
	"github.com/evenyosua18/go-project-template/app/entity"
	"github.com/evenyosua18/go-project-template/app/repository/db/example"
)

type IExampleUsecase interface {
	Get(ctx context.Context, request entity.GetExampleRequest) (entity.GetExampleResponse, error)
}

type UsecaseExample struct {
	exampleRepo example.IExampleRepository
}

func NewExampleUsecase(exampleRepo example.IExampleRepository) IExampleUsecase {
	return &UsecaseExample{
		exampleRepo: exampleRepo,
	}
}
