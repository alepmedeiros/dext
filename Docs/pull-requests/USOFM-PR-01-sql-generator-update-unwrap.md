## Summary

Fixes `PersistUpdate` / `GenerateUpdate` when the primary key or optimistic-lock **version** column is mapped from **`Prop<T>`** (Smart Types from `Dext.Core.SmartTypes`). Those properties surface as **`TValue`** with `Kind = tkRecord`, so binding them with `[DbType]` / explicit `ftInteger` caused **`TValue.AsInteger`** / RTTI failures.

## Problem

- `FParams.Add` for **PK** and **version (WHERE)** ran **before** `TryUnwrapSmartValue`, unlike SET columns.
- `Update` SQL parameters for `IntType` PKs could reach FireDAC as wrapped records instead of plain integers.

## Solution

- For **`IsVersion`**: run nullable handling (if any) + **`TryUnwrapSmartValue`** **before** the first `FParams.Add` (old version in WHERE).
- For **`IsPK`**: same nullable + **`TryUnwrapSmartValue`** before `FParams.Add` for the WHERE clause.

## Files

- `Sources/Data/Dext.Specifications.SQL.Generator.pas`

## Testing

- `Web.Dext.Starter.Admin` (or any entity with `IntType` PK): **PUT** / **SaveChanges** after edit should succeed without `AsInteger` / typecast errors on PK param `p1`.
