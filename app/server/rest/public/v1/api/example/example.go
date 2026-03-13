package example

import (
	"github.com/evenyosua18/go-project-template/app/usecase/example"
)

type ApiExample struct {
	exampleUsecase example.IExampleUsecase
}

func NewExampleApi(exampleUsecase example.IExampleUsecase) *ApiExample {
	return &ApiExample{
		exampleUsecase: exampleUsecase,
	}
}
