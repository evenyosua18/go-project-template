package example

import (
	"github.com/evenyosua18/go-project-template/app/entity"
	"github.com/evenyosua18/ego/code"
	"github.com/evenyosua18/ego/http"
)

func (a *ApiExample) Get(c http.Context) error {
	var in entity.GetExampleRequest
	if err := c.BindQuery(&in); err != nil {
		return c.ResponseError(code.Wrap(err, code.BadRequestError))
	}

	res, err := a.exampleUsecase.Get(c.Context(), in)
	if err != nil {
		return c.ResponseError(err)
	}

	return c.ResponseSuccess(res)
}
