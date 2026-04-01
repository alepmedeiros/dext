# Dext Web Driver Architecture Proposal

To enable Dext ORM to consume external REST APIs as if they were databases, we need a driver implementation that translates IDb interfaces into HTTP/JSON operations.

## 1. Interface Implementation

### `TWebConnection = class(TInterfacedObject, IDbConnection)`
- **Properties**: `BaseUrl`, `AuthToken`, `Timeout`.
- **Method `CreateCommand`**: Returns a `TWebCommand`.

### `TWebCommand = class(TInterfacedObject, IDbCommand)`
- **Function `ExecuteQuery`**: 
  - Converts the SQL (or Specification) into an HTTP request.
  - Sends the request using `THTTPClient`.
  - Parses the response body as a JSON array.
  - Returns a `TWebReader`.

### `TWebReader = class(TInterfacedObject, IDbReader)`
- **Internal State**: `FJsonArray: TJSONArray`, `FCurrentIndex: Integer`.
- **Method `Next`**: Increments `FCurrentIndex`.
- **Method `GetValue(AIndex: Integer)`**:
  - Get column name from index.
  - Find value in `FJsonArray.Items[FCurrentIndex]`.
  - **Logic**:
    ```pascal
    function TWebReader.GetValue(AIndex: Integer): TValue;
    var
      LKey: string;
      LObj: TJSONObject;
      LValue: TJSONValue;
    begin
      LKey := GetColumnName(AIndex);
      LObj := FJsonArray.Items[FCurrentIndex] as TJSONObject;
      
      if not LObj.TryGetValue(LKey, LValue) or LValue.IsNull then
        Exit(TValue.Empty); // Consistent with FireDAC drivers
        
      Result := TJsonValueToTValue(LValue);
    end;
    ```

## 2. Key Benefits
1. **Consistency**: `Nullable<T>` will work out-of-the-box because `TValue.Empty` is used for missing/null JSON fields.
2. **Reuse**: All hydration logic in `TDbSet` (Type Converters, Attributes, Proxies) remains untouched.
3. **Integration**: Allows hybrid applications where some entities are Local (SQL) and others are Remote (Microservices).

## 3. Remote Specification Mapping
Since sending Raw SQL to a Web API is often insecure, this driver could prioritize mapping `ISpecification` directly to Query String parameters:
- `Ctx.Entities<TPerson>.Where(p => p.Age > 18).ToList;`
- Becomes: `GET /person?age_gt=18` (Mapped by the driver).
