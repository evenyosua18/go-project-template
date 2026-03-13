package example

import (
	"context"
	"github.com/evenyosua18/go-project-template/app/entity"
)

func (s *UsecaseExample) Get(ctx context.Context, request entity.GetExampleRequest) (entity.GetExampleResponse, error) {
	return entity.GetExampleResponse{
		Example: request.Example,
	}, nil
}
