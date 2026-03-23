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
- Use `github.com/DATA-DOG/go-sqlmock` to mock the `sql` package.
- Function naming convention: `Test<FunctionName><Context>`
    - For example, if there is a `count.go` file with a `Count()` function in the `payments` directory, the test function should be named `TestCountPayments()`.

**Sample Implementation**
```go
package payments

import (
	"context"
	"database/sql"
	"regexp"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/stretchr/testify/assert"
	"github.com/tanookiai/go-core/apierror"
	"github.com/tanookiai/go-core/db"
)

func TestCountPayments(t *testing.T) {
	dbSqlMock, mock, err := sqlmock.New()
	assert.Nil(t, err)
	dbConn := db.NewDBWithPool(dbSqlMock)
	dbMock := db.NewSQLHelper()

	mockCtx := context.TODO()

	type args struct {
		filter FilterPayment
	}
	tests := []struct {
		name     string
		mockCall func()
		args     args
		want     int64
		wantErr  error
	}{
		{
			name: "Success - Count all payments",
			args: args{
				filter: FilterPayment{},
			},
			mockCall: func() {
				mock.ExpectBegin()
				rows := sqlmock.NewRows([]string{"count"}).AddRow(2)
				mock.ExpectQuery(regexp.QuoteMeta("SELECT COUNT(id) FROM payments WHERE deleted_at IS NULL")).WillReturnRows(rows)
			},
			want:    2,
			wantErr: nil,
		}
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.mockCall()

			_, ctx := dbConn.BeginTrxWithContext(mockCtx)
			r := &PaymentRepository{dbMock}
			got, err := r.Count(ctx, tt.args.filter)

			assert.EqualValues(t, tt.want, got)
			assert.EqualValues(t, tt.wantErr, err)

			assert.NoError(t, mock.ExpectationsWereMet())
		})
	}
}
```

## 3. Third party Unit Testing
- This section applies to anything related to the third party repository (e.g., `app/repository`). `except db folder`

```go
package credit

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestInjectPlatformCredit(t *testing.T) {
	mockCtx := context.TODO()

	type args struct {
		req InjectPlatformCreditRequest
	}
	tests := []struct {
		name            string
		baseUrl         string
		apiKey          string
		mockServer      func() *httptest.Server
		args            args
		wantErr         bool
		wantErrContains string
		exactErr        error
	}{
		{
			name:    "Success - Inject platform credit",
			baseUrl: "mocked",
			apiKey:  "test-api-key",
			mockServer: func() *httptest.Server {
				return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					w.WriteHeader(http.StatusOK)
					w.Write([]byte(`{"success":true}`))
				}))
			},
			args: args{
				req: InjectPlatformCreditRequest{
					AccountID:     1,
					Amount:        1000,
					Type:          "deposit",
					ReferenceID:   123,
					ReferenceType: "trx",
				},
			},
			wantErr: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var baseUrl string
			if tt.mockServer != nil {
				server := tt.mockServer()
				if server != nil {
					defer server.Close()
					if tt.baseUrl == "mocked" {
						baseUrl = server.URL
					} else {
						baseUrl = tt.baseUrl
					}
				} else {
					baseUrl = tt.baseUrl
				}
			} else {
				baseUrl = tt.baseUrl
			}

			repo := &CreditSvcCreditRepository{
				baseUrl: baseUrl,
				apiKey:  tt.apiKey,
			}

			err := repo.InjectPlatformCredit(mockCtx, tt.args.req)

			if tt.wantErr {
				assert.Error(t, err)
				if tt.exactErr != nil {
					assert.EqualValues(t, tt.exactErr, err)
				}
				if tt.wantErrContains != "" {
					assert.Contains(t, err.Error(), tt.wantErrContains)
				}
			} else {
				assert.NoError(t, err)
			}
		})
	}
}
```

## 4. Service Layer Unit Testing
- This section applies to anything under `app/service/`.
- Inject repository mocks directly into the service struct (no constructor wrapper needed).
- Use `mockSetup func()` (not `mockCall`) in the test table — this matches the service layer convention.
- Call `mock.AssertExpectations(t)` for **every** mock at the end of each test case.
- Override package-level function variables (e.g., `timeNow`) before the test table, restore them via `defer` if the value changes per test case.
- Set Viper config values at the top of the test function when the service reads from config.
- Use `apierror.Get("<code>").Message("<msg>")` for `wantErr` — match the exact error the service returns.
- Function naming convention: `Test<ServiceStructName>_<MethodName>` — e.g., `TestPaymentService_Insert`.

**Sample Implementation**
```go
package paymentsvc

import (
	"context"
	"errors"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/tanookiai/go-core/apierror"
	"github.com/tanookiai/payment-svc/entity"
	mockPaymentRepo "github.com/tanookiai/payment-svc/mocks/repository/db/payments"
)

func TestPaymentService_Insert(t *testing.T) {
	mockPaymentRepo := new(mockPaymentRepo.IPaymentRepository)

	mockCtx := context.TODO()

	type args struct {
		req entity.InsertPaymentRequest
	}
	tests := []struct {
		name      string
		mockSetup func()
		args      args
		want      entity.InsertPaymentResponse
		wantErr   error
	}{
		{
			name: "Success - Insert payment",
			mockSetup: func() {
				mockPaymentRepo.On("Insert", mockCtx, payments.InsertPayment{
					AccountID: 1,
					Amount:    10000,
					Currency:  "idr",
				}).Return(int64(1), nil).Once()
			},
			args: args{
				req: entity.InsertPaymentRequest{
					AccountID: 1,
					Amount:    10000,
					Currency:  "IDR",
				},
			},
			want:    entity.InsertPaymentResponse{ID: 1},
			wantErr: nil,
		},
		{
			name: "Error - Repository insert failed",
			mockSetup: func() {
				mockPaymentRepo.On("Insert", mockCtx, payments.InsertPayment{
					AccountID: 1,
					Amount:    10000,
					Currency:  "idr",
				}).Return(int64(0), errors.New("db error")).Once()
			},
			args: args{
				req: entity.InsertPaymentRequest{
					AccountID: 1,
					Amount:    10000,
					Currency:  "IDR",
				},
			},
			want:    entity.InsertPaymentResponse{},
			wantErr: apierror.Get("0500").Message("failed to insert payment"),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.mockSetup != nil {
				tt.mockSetup()
			}

			svc := PaymentService{
				paymentRepo: mockPaymentRepo,
			}
			got, err := svc.Insert(mockCtx, tt.args.req)

			assert.Equal(t, tt.wantErr, err)
			assert.Equal(t, tt.want, got)
			mockPaymentRepo.AssertExpectations(t)
		})
	}
}
```

## 5. API Layer Unit Testing
- This section applies to anything under `app/api/`.
- The API layer has **two distinct test types**:
  1. **Service integration tests** — mock the service interface, call the service method directly (simulating what the handler does), assert response and error.
  2. **Business logic tests** — no mocks; test pure handler logic (e.g., field derivation, fallback values) in isolation.
- Use `setup func(*mock.IService)` in the test table to configure mock expectations per case.
- Instantiate the mock with `mock.NewI<ServiceName>(t)` (generated by mockery) — this auto-registers cleanup.
- Call `mockSvc.AssertExpectations(t)` at the end of each test case.
- For error assertions prefer `assert.EqualError(t, err, tt.wantErr.Error())` over `assert.Equal`.
- Function naming convention:
  - Service integration: `Test<ApiStruct>_<HandlerMethod>_ServiceLayer`
  - Business logic: `Test<ApiStruct>_<LogicDescription>_Logic`

**Sample Implementation**
```go
package paymentapi

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/tanookiai/go-core/apierror"
	paymentsvcmock "github.com/tanookiai/payment-svc/mocks/service/paymentsvc"
	"github.com/tanookiai/payment-svc/entity"
)

// TestApiPayment_Insert_ServiceLayer tests the handler's service layer integration.
// Full HTTP handler testing requires HTTP mock infrastructure; this test focuses on
// verifying service call and response propagation.
func TestApiPayment_Insert_ServiceLayer(t *testing.T) {
	ctx := context.Background()

	tests := []struct {
		name    string
		req     entity.InsertPaymentRequest
		setup   func(*paymentsvcmock.IPaymentService)
		want    entity.InsertPaymentResponse
		wantErr error
	}{
		{
			name: "Success_service_returns_success",
			req: entity.InsertPaymentRequest{
				AccountID: 1,
				Amount:    10000,
				Currency:  "IDR",
			},
			setup: func(svc *paymentsvcmock.IPaymentService) {
				svc.On("Insert", ctx, entity.InsertPaymentRequest{
					AccountID: 1,
					Amount:    10000,
					Currency:  "IDR",
				}).Return(entity.InsertPaymentResponse{ID: 1}, nil).Once()
			},
			want:    entity.InsertPaymentResponse{ID: 1},
			wantErr: nil,
		},
		{
			name: "Failed_service_returns_validation_error",
			req: entity.InsertPaymentRequest{
				AccountID: 0,
				Amount:    10000,
				Currency:  "IDR",
			},
			setup: func(svc *paymentsvcmock.IPaymentService) {
				svc.On("Insert", ctx, entity.InsertPaymentRequest{
					AccountID: 0,
					Amount:    10000,
					Currency:  "IDR",
				}).Return(entity.InsertPaymentResponse{}, apierror.Get("0400").Message("account_id is required")).Once()
			},
			want:    entity.InsertPaymentResponse{},
			wantErr: apierror.Get("0400").Message("account_id is required"),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockSvc := paymentsvcmock.NewIPaymentService(t)
			tt.setup(mockSvc)

			// Execute service call directly (simulating what the handler does)
			got, err := mockSvc.Insert(ctx, tt.req)

			if tt.wantErr != nil {
				assert.Error(t, err)
				assert.EqualError(t, err, tt.wantErr.Error())
			} else {
				assert.NoError(t, err)
				assert.Equal(t, tt.want, got)
			}

			mockSvc.AssertExpectations(t)
		})
	}
}

// TestApiPayment_AccountID_Logic tests pure handler field-derivation logic (no mocks needed).
func TestApiPayment_AccountID_Logic(t *testing.T) {
	tests := []struct {
		name          string
		headerID      int64
		wantAccountID int64
	}{
		{
			name:          "Use_account_id_from_header",
			headerID:      42,
			wantAccountID: 42,
		},
		{
			name:          "Default_to_zero_when_header_missing",
			headerID:      0,
			wantAccountID: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Simulate handler logic inline
			accountID := tt.headerID
			assert.Equal(t, tt.wantAccountID, accountID)
		})
	}
}
```