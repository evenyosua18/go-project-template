package example

import (
	"context"
	// "github.com/tanookiai/go-core/db" // Adjust this if you use another library
)

type IExampleRepository interface {
	Get(ctx context.Context, filter FilterExample) (Example, error)
}

type RepositoryExample struct {
	// db db.SQLHelper
}

func NewExampleRepository() IExampleRepository { // func NewExampleRepository(db db.SQLHelper)
	return &RepositoryExample{
		// db: db,
	}
}
