package main

import "github.com/evenyosua18/go-project-template/cmd"

// @title           {{ .ProjectName }} API
// @version         1.0
// @description     {{ .ProjectName }} API documentation.
// @securityDefinitions.apikey BearerAuth
// @in header
// @name Authorization
// @description Type "Bearer" followed by a space and JWT token.
func main() {
	cmd.Execute()
}
