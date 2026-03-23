GOPATH := $(shell go env GOPATH)
WIRE := $(GOPATH)/bin/wire

run:
	@if [ "$(SWAG)" = "1" ] || [ "$(SWAG)" = "true" ]; then \
		make swagger; \
	fi
	@go run main.go

wire:
	@$(WIRE) ./app/server/rest/public/v1/container

swagger:
	@echo "-- regenerating swagger docs --"
	@go run github.com/swaggo/swag/cmd/swag@v1.16.6 init

test:
	@echo "-- run repository package unit test --"
	@go test -failfast ./app/repository/db/* --cover
	@echo "-- run usecase package unit test --"
	@go test -failfast ./app/usecase/* --cover
	@echo "-- run rest server package unit test --"
	@go test -failfast ./app/server/rest/public/v1/api/* --cover

# to run a specific test file
# example: make test-file TYPE=db FOLDER=access_tokens FILE=authorize_test
# example: make test-file TYPE=usecase FOLDER=access_token FILE=authorize_test ARGS=-v
# example: make test-file TYPE=usecase FOLDER=access_token FILE=authorize_test ARGS="-v -cover"
test-file:
	@if [ -z "$(TYPE)" ] || [ -z "$(FOLDER)" ] || [ -z "$(FILE)" ]; then \
		echo "❌ Usage: make test-file TYPE=db|usecase|public|service|entity FOLDER=folder_name FILE=test_file_name [ARGS=-v -cover]"; \
		echo "   Example: make test-file TYPE=db FOLDER=access_tokens FILE=authorize_test"; \
		exit 1; \
	fi; \
	case "$(TYPE)" in \
		db) BASE_PATH="./app/repository/db" ;; \
		usecase) BASE_PATH="./app/usecase" ;; \
		public) BASE_PATH="./app/server/rest/public/v1/api" ;; \
		service) BASE_PATH="./app/server/rest/service/v1/api" ;; \
		entity) BASE_PATH="./app/entity" ;; \
		*) echo "❌ Invalid TYPE: $(TYPE) (must be db|usecase|public|service|entity)"; exit 1 ;; \
	esac; \
	echo "-- running test file: $$BASE_PATH/$(FOLDER)/$(FILE).go --"; \
	go test $$BASE_PATH/$(FOLDER) $(ARGS)

# to help get coverage value for specific layer
# example: make coverage TYPE=db FOLDER=access_tokens
coverage:
	@if [ -z "$(TYPE)" ] || [ -z "$(FOLDER)" ]; then \
		echo "❌ Usage: make coverage TYPE=db|usecase|public|service|entity FOLDER=folder_name"; \
		exit 1; \
	fi; \
	case "$(TYPE)" in \
		db) BASE_PATH="./app/repository/db" ;; \
		usecase) BASE_PATH="./app/usecase" ;; \
		public) BASE_PATH="./app/server/rest/public/v1/api" ;; \
		service) BASE_PATH="./app/server/rest/service/v1/api" ;; \
		entity) BASE_PATH="./app/entity" ;; \
		*) echo "❌ Invalid TYPE: $(TYPE) (must be db|usecase|public|service|entity)"; exit 1 ;; \
	esac; \
	echo "-- checking coverage $$BASE_PATH/$(FOLDER) --"; \
	go test $$BASE_PATH/$(FOLDER) -coverprofile=coverage.out; \
	go tool cover -html=coverage.out

# to add mock configuration based on the given request and regenerate mock files
# example: make add-mock PKG=usecase NAME=refresh_token INTERFACE=IRefreshTokenUsecase
MOCKERY_FILE=.mockery.yaml
MOCKERY_ROOT_PATH=github.com/evenyosua18/go-project-template/app
add-mock:
	@if [ -z "$(INTERFACE)" ] || [ -z "$(NAME)" ] || [ -z "$(PKG)" ]; then \
		echo "❌ Please provide INTERFACE, NAME and PKG. Example: make add-mock PKG=db NAME=authorization_codes INTERFACE=IAccessTokenRepository"; \
		exit 1; \
	fi; \
	case "$(PKG)" in \
		db) BASE_PACKAGE="repository/db" ;; \
		repository) BASE_PACKAGE="repository" ;; \
		usecase) BASE_PACKAGE="usecase" ;; \
		*) echo "❌ Invalid PKG: $(PKG) (must be db|repository|usecase)"; exit 1 ;; \
	esac; \
	echo "Adding mock config for $(ROOT_PATH)/$$BASE_PACKAGE/$(NAME) ..."; \
	echo "  $(MOCKERY_ROOT_PATH)/$$BASE_PACKAGE/$(NAME):" >> $(MOCKERY_FILE); \
	echo "    interfaces:" >> $(MOCKERY_FILE); \
	echo "      $(INTERFACE):" >> $(MOCKERY_FILE); \
	echo "        configs:" >> $(MOCKERY_FILE); \
	echo "          - filename: $$BASE_PACKAGE/$(NAME)/$(NAME).go" >> $(MOCKERY_FILE); \
	echo "✅ Mock config appended."
	echo "Generating Mock..."
	@mockery