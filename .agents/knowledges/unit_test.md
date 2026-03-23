# Backend Unit Testing Rules & Standards

## 1. General Rules
- Avoid using `mock.Any` or `mock.Anything`. Always specify explicit arguments in mock expectations, and specify call counts (`.Once()`, `.Twice()`, etc.).
- Use `wantErr` to test exact error messages and types for clearer test assertions.
- Create test files alongside the source file with the suffix `_test.go` (e.g., `insert_test.go` for `insert.go`).
- Use the **Table-Driven Tests** pattern (idiomatic Go).
- Utilize the `go test` standard library.
- Make sure to stub and assert your mocked interfaces accurately (e.g., `mockRepo.On("Insert", expectedData).Return(nil)`).

## 2. Database Unit Testing
- This section applies to anything related to the database repository (e.g., `app/repository/db`).
- Use `github.com/evenyosua18/ego/stub/sqldb` to stub the `sqldb` package.
- Use `github.com/evenyosua18/ego/stub/tracer` to stub the `tracer` package.
- Function naming convention: `Test<FunctionName><Context>`
    - For example, if there is a `get.go` file with a `Get()` function in the `access_tokens` directory, the test function should be named `TestRepositoryAccessToken_Get(t *testing.T)`.

**Sample Implementation**
```go
package access_tokens

import (
	"context"
	"database/sql"
	"fmt"
	"testing"

	"github.com/evenyosua18/ego/sqldb"
	"github.com/evenyosua18/ego/stub/clock"
	stubsqldb "github.com/evenyosua18/ego/stub/sqldb"
	stubtracer "github.com/evenyosua18/ego/stub/tracer"
	"github.com/evenyosua18/ego/tracer"
)

func TestRepositoryAccessToken_Get(t *testing.T) {
	// function request parameter
	type args struct {
		ctx    context.Context
		filter FilterAccessToken
	}

	filter := FilterAccessToken{
		Id: sql.NullInt64{Valid: true, Int64: 1},
	}
	
	query, qargs := filter.SelectStatement(filter)

	expectedArgs := qargs

	expectedResult := AccessToken{
		Id:         1,
		UserId:     sql.NullInt64{Valid: true, Int64: 1},
		ClientId:   sql.NullString{Valid: true, String: "TEST"},
		Scopes:     "TEST",
		ExpiredAt:  clock.Stub(),
		GrantType:  "TEST",
		AccessType: "TEST",
	}

	expectedResultValues := []any{
		expectedResult.Id,
		expectedResult.UserId,
		expectedResult.ClientId,
		expectedResult.Scopes,
		expectedResult.ExpiredAt,
		expectedResult.GrantType,
		expectedResult.AccessType,
	}

	tests := []struct {
		name    string
		args    args
		want    AccessToken
		wantErr error
		tracer  tracer.Tracer
		db      sqldb.IDbManager
	}{
		{
			name: "success get access token",
			db: &stubsqldb.StubDbManager{
				StubExecutor: stubsqldb.StubExecutor{
					ExpectedQuery: query,
					ExpectedArgs:  expectedArgs,
					QueryRowValues: expectedResultValues,
				},
			},
			tracer: &stubtracer.StubTracer{},
			args: args{
				ctx:    context.TODO(),
				filter: filter,
			},
			want:    expectedResult,
			wantErr: nil,
		},
		{
			name: "executor error",
			args: args{
				ctx:    context.TODO(),
				filter: filter,
			},
			want:    AccessToken{},
			wantErr: fmt.Errorf(`TEST`),
			tracer:  &stubtracer.StubTracer{},
			db: &stubsqldb.StubDbManager{
				ExecutorErr: fmt.Errorf(`TEST`),
			},
		},
		{
			name: "query row scan error",
			args: args{
				ctx:    context.TODO(),
				filter: filter,
			},
			want:    AccessToken{},
			wantErr: sql.ErrNoRows,
			tracer:  &stubtracer.StubTracer{},
			db: &stubsqldb.StubDbManager{
				StubExecutor: stubsqldb.StubExecutor{
					ExpectedQuery: query,
					ExpectedArgs:  expectedArgs,
					QueryRowErr: sql.ErrNoRows,
				},
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// set up repository
			r := &RepositoryAccessToken{
				tracer: tt.tracer,
				db:     tt.db,
			}

			// get
			got, err := r.Get(tt.args.ctx, tt.args.filter)

			// expected error
			if tt.wantErr != nil && err.Error() != tt.wantErr.Error() {
				t.Errorf("Get() error = %v, wantErr %v", err, tt.wantErr)
				return
			}

			// expected value via simple struct comparison
			if got.Id != tt.want.Id || got.ClientId != tt.want.ClientId || got.UserId != tt.want.UserId || got.Scopes != tt.want.Scopes || got.GrantType != tt.want.GrantType || got.AccessType != tt.want.AccessType {
				t.Errorf("Get() got = %v, want %v", got, tt.want)
			}
            
            // Checking the time to not get affected by precision matches issue
            // We use simple Unix validation
            if (!got.ExpiredAt.IsZero() || !tt.want.ExpiredAt.IsZero()) && got.ExpiredAt.Unix() != tt.want.ExpiredAt.Unix() {
                t.Errorf("Get() time ExpiredAt got = %v, want %v", got.ExpiredAt, tt.want.ExpiredAt)
            }
		})
	}
}
```

## 3. Third party Unit Testing
- This section applies to anything related to the third party repository (e.g., `app/repository`). `except db folder`
- Third party can be microservice or external service

```go
```

## 4. Usecase Layer Unit Testing
- This section applies to anything under `app/usecase/`.
- Inject repository mocks directly into the usecase struct (no constructor wrapper needed).
- Set `config.SetTestConfig()` to stub config value
- Use `codes.Get("<code>").Message("<msg>")` for `wantErr` — match the exact error the service returns.
- Function naming convention: `Test<UsecaseStructName>_<MethodName>` — e.g., `TestUsecaseRefreshToken_GenerateRefreshToken`.

**Sample Implementation**
```go
package refresh_token

import (
	"context"
	"errors"
	"reflect"
	"testing"
	"time"

	"github.com/evenyosua18/auth-svc/app/entity"
	mockRefreshToken "github.com/evenyosua18/auth-svc/app/mocks/repository/db/refresh_tokens"
	"github.com/evenyosua18/auth-svc/app/repository/db/refresh_tokens"
	"github.com/evenyosua18/ego/config"
	"github.com/evenyosua18/ego/cryptox"
	"github.com/evenyosua18/ego/sqldb"
	"github.com/evenyosua18/ego/stub"
	"github.com/evenyosua18/ego/stub/clock"
	stubdb "github.com/evenyosua18/ego/stub/sqldb"
	stubtracer "github.com/evenyosua18/ego/stub/tracer"
	"github.com/evenyosua18/ego/tracer"
)

func TestUsecaseRefreshToken_GenerateRefreshToken(t *testing.T) {
	type fields struct {
		tracer             tracer.Tracer
		db                 sqldb.IDbManager
		timeNow            stub.TimeNowFunc
		generateRandString stub.GenerateRandomStringFunc
	}

	type args struct {
		ctx     context.Context
		request entity.GenerateRefreshTokenRequest
	}

	refreshToken, hashedRefreshToken := cryptox.HashValue("TEST")

	tests := []struct {
		name    string
		fields  fields
		args    args
		want    entity.GenerateRefreshTokenResponse
		wantErr error
		mock    func(refreshTokenRepo refresh_tokens.IRefreshTokenRepository)
	}{
		{
			name: "insert refresh token error",
			fields: fields{
				tracer: &stubtracer.StubTracer{},
				db:     &stubdb.StubDbManager{},
				timeNow: func() time.Time {
					return clock.Stub()
				},
				generateRandString: func(length int) string {
					return "TEST"
				},
			},
			args: args{
				ctx: context.TODO(),
				request: entity.GenerateRefreshTokenRequest{
					AccessTokenId: 1,
				},
			},
			want:    entity.GenerateRefreshTokenResponse{},
			wantErr: codes.Get("0500").Message("failed to generate refresh token"),
			mock: func(refreshTokenRepo refresh_tokens.IRefreshTokenRepository) {
				// setup variable
				ctx := context.TODO()

				mockAuthUserRepo := refreshTokenRepo.(*mockRefreshToken.MockIRefreshTokenRepository)

				// mock insert
				mockAuthUserRepo.EXPECT().Insert(ctx, refresh_tokens.RefreshToken{
					AccessTokenId: 1,
					ExpiredAt:     clock.StubValue.Add(time.Hour),
					RefreshToken:  hashedRefreshToken,
					Attempts:      1,
				}).Return(0, codes.Get("0500").Message("failed to generate refresh token")).Once()
			},
		},
		{
			name: "success generate refresh token",
			fields: fields{
				tracer: &stubtracer.StubTracer{},
				db:     &stubdb.StubDbManager{},
				timeNow: func() time.Time {
					return clock.Stub()
				},
				generateRandString: func(length int) string {
					return "TEST"
				},
			},
			args: args{
				ctx: context.TODO(),
				request: entity.GenerateRefreshTokenRequest{
					AccessTokenId: 1,
				},
			},
			want: entity.GenerateRefreshTokenResponse{
				RefreshToken:   refreshToken,
				RefreshTokenId: 1,
			},
			wantErr: nil,
			mock: func(refreshTokenRepo refresh_tokens.IRefreshTokenRepository) {
				// setup variable
				ctx := context.TODO()

				mockAuthUserRepo := refreshTokenRepo.(*mockRefreshToken.MockIRefreshTokenRepository)

				// mock insert
				mockAuthUserRepo.EXPECT().Insert(ctx, refresh_tokens.RefreshToken{
					AccessTokenId: 1,
					ExpiredAt:     clock.StubValue.Add(time.Hour),
					RefreshToken:  hashedRefreshToken,
					Attempts:      1,
				}).Return(1, nil).Once()
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// set test config
			config.SetTestConfig(map[string]any{
				"refresh_token.length":           5,
				"refresh_token.expired_duration": "1h",
			})

			// set repo
			refreshTokenRepo := mockRefreshToken.NewMockIRefreshTokenRepository(t)

			u := &UsecaseRefreshToken{
				tracer:           tt.fields.tracer,
				db:               tt.fields.db,
				refreshTokenRepo: refreshTokenRepo,
			}

			// set stub function
			if tt.fields.timeNow != nil {
				u.timeNow = tt.fields.timeNow
			}

			if tt.fields.generateRandString != nil {
				u.generateRandString = tt.fields.generateRandString
			}

			// run mock
			if tt.mock != nil {
				tt.mock(refreshTokenRepo)
			}

			got, err := u.GenerateRefreshToken(tt.args.ctx, tt.args.request)

			// expected error
			if tt.wantErr != nil && err.Error() != tt.wantErr.Error() {
				t.Errorf("got an error = %v, wantErr %v", err, tt.wantErr)
				return
			}

			if !reflect.DeepEqual(got, tt.want) {
				t.Errorf("GenerateRefreshToken() got = %v, want %v", got, tt.want)
			}
		})
	}
}
```

## 5. API Layer Unit Testing
- This section applies to anything under `app/server/rest`.
- The API layer has **two distinct test types**:
  1. **Usecase integration tests** — mock the usecase interface, call the usecase method directly (simulating what the handler does), assert response and error.
- For error assertions prefer `assert.EqualError(t, err, tt.wantErr.Error())` over `assert.Equal`.
- Function naming convention `Test<ApiStruct>_<HandlerMethod>_ServiceLayer`

**Sample Implementation**
```go
package access_token

import (
	"bytes"
	"encoding/json"
	"errors"
	"net/http/httptest"
	"testing"

	"github.com/evenyosua18/auth-svc/app/entity"
	mockAccessTokenUc "github.com/evenyosua18/auth-svc/app/mocks/usecase/access_token"
	"github.com/evenyosua18/ego/config"
	"github.com/evenyosua18/ego/http"
	stubtracer "github.com/evenyosua18/ego/stub/tracer"
	"github.com/gofiber/fiber/v3"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
)

func TestApiToken_RefreshToken(t *testing.T) {
	config.SetTestConfig(map[string]any{})

	type args struct {
		body any // Can be string or a struct that will be marshaled into JSON
	}
	tests := []struct {
		name         string
		args         args
		wantCode     int
		wantResponse *entity.TokenGenerationRefreshResponse
		setupMock    func(uc *mockAccessTokenUc.MockIAccessTokenUsecase)
	}{
		{
			name: "error binding request body",
			args: args{
				body: `invalid_json`, // Sending invalid raw JSON string
			},
			wantCode: fiber.StatusInternalServerError,
		},
		{
			name: "error validate request",
			args: args{
				// Sending the struct directly
				body: entity.TokenGenerationRefreshRequest{
					GrantType:    "invalid", // This will fail validation
					RefreshToken: "TEST",
				},
			},
			wantCode:     fiber.StatusBadRequest,
			wantResponse: nil,
		},
		{
			name: "error from usecase",
			args: args{
				body: entity.TokenGenerationRefreshRequest{
					GrantType:    "refresh_token",
					RefreshToken: "TEST",
				},
			},
			wantCode:     fiber.StatusInternalServerError,
			wantResponse: nil,
			setupMock: func(uc *mockAccessTokenUc.MockIAccessTokenUsecase) {
				uc.EXPECT().RefreshAccessToken(mock.Anything, entity.TokenGenerationRefreshRequest{
					GrantType:    "refresh_token",
					RefreshToken: "TEST",
				}).Return(entity.TokenGenerationRefreshResponse{}, errors.New("TEST")).Once()
			},
		},
		{
			name: "success refresh token",
			args: args{
				body: entity.TokenGenerationRefreshRequest{
					GrantType:    "refresh_token",
					RefreshToken: "TEST",
				},
			},
			wantCode: fiber.StatusOK,
			wantResponse: &entity.TokenGenerationRefreshResponse{
				AccessToken:  "access_token",
				RefreshToken: "refresh_token",
			},
			setupMock: func(uc *mockAccessTokenUc.MockIAccessTokenUsecase) {
				uc.EXPECT().RefreshAccessToken(mock.Anything, entity.TokenGenerationRefreshRequest{
					GrantType:    "refresh_token",
					RefreshToken: "TEST",
				}).Return(entity.TokenGenerationRefreshResponse{
					AccessToken:  "access_token",
					RefreshToken: "refresh_token",
				}, nil).Once()
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			app := http.NewRouter(http.RouteConfig{DisableAuthChecker: true})
			mockUc := mockAccessTokenUc.NewMockIAccessTokenUsecase(t)

			if tt.setupMock != nil {
				tt.setupMock(mockUc)
			}

			apiToken := NewTokenApi(&stubtracer.StubTracer{}, mockUc)
			app.Post("/ms/auth/v1/token/refresh", apiToken.RefreshToken)

			// Determine body content dynamically based on the type of tt.args.body
			var reqBody *bytes.Buffer
			if strBody, ok := tt.args.body.(string); ok {
				// Raw string payload
				reqBody = bytes.NewBuffer([]byte(strBody))
			} else {
				// Struct payload implicitly to be encoded into JSON
				jsonBytes, err := json.Marshal(tt.args.body)
				if err != nil {
					t.Fatalf("Failed to marshal request body: %v", err)
				}
				reqBody = bytes.NewBuffer(jsonBytes)
			}

			req := httptest.NewRequest("POST", "/ms/auth/v1/token/refresh", reqBody)
			req.Header.Set("Content-Type", "application/json")

			resp, err := app.Test(req)
			if err != nil {
				t.Fatalf("Failed to execute request: %v", err)
			}

			if resp.StatusCode != tt.wantCode {
				buf := make([]byte, 1024)
				n, _ := resp.Body.Read(buf)
				t.Errorf("ApiToken.RefreshToken() status code = %v, wantCode %v. Body: %s", resp.StatusCode, tt.wantCode, string(buf[:n]))
			}

			// Verify Response
			if tt.wantResponse != nil {
				buf := make([]byte, 2048)
				n, _ := resp.Body.Read(buf)

				// Typical successful response formatting check.
				// By default, ego's basic ResponseSuccess maps to this wrapper format
				var responseBody struct {
					Data entity.TokenGenerationRefreshResponse `json:"data"`
				}
				// If the server directly returning un-wrapped JSON simply read from original type, but usually is wrapped into "data"
				err := json.Unmarshal(buf[:n], &responseBody)
				if err == nil && responseBody.Data.AccessToken != "" {
					assert.Equal(t, *tt.wantResponse, responseBody.Data)
				} else {
					// Fallback to directly verifying against the struct without root node parsing in case ego changed wrapping structure
					var unwrappedResponseBody entity.TokenGenerationRefreshResponse
					err = json.Unmarshal(buf[:n], &unwrappedResponseBody)
					if err != nil {
						t.Fatalf("Failed to unmarshal test response body: %v. Raw Body: %s", err, string(buf[:n]))
					}
					assert.Equal(t, *tt.wantResponse, unwrappedResponseBody)
				}
			}
		})
	}
}
```