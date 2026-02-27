# 📦 Dext.Collections

`Dext.Collections` is the in-memory data management engine of the **Dext Framework**. Unlike standard Delphi collections (`System.Generics.Collections`), Dext's collections were designed to solve the three major challenges of modern Object Pascal development: **Memory Leaks (Ownership)**, **Verbosity (LINQ)**, and **Compilation Performance**.

## 🚀 Why use Dext.Collections?

1. **Automatic Memory Safety (ARC-like)**: Collections are interface-based (`IList<T>`, `IDictionary<K,V>`). You will never need to call `.Free` on a list returned by a method again.
2. **Ownership Management**: Native support for `OwnsObjects`. If you create a list of objects, it knows when to destroy the elements and when to just keep the reference.
3. **Functional API (LINQ)**: Powerful methods like `Where`, `Select`, `Any`, `All`, `First`, `OrderBy` integrated directly into the interface.
4. **ORM Integration**: `Dext.Entity` uses these collections to return search results and manage relationships (HasMany), allowing in-memory filtering with the same database syntax.

---

## 🛠️ Usage Guide

### 1. Declaration and Creation

Always prefer using **Interfaces** to ensure automatic memory management.

```delphi
uses
  Dext.Collections;

var
  Users: IList<TUser>;
  Settings: IDictionary<string, string>;
begin
  // Object List (Automatically destroys objects by default)
  Users := TCollections.CreateObjectList<TUser>; 
  
  // Simple List (Integers, Records, Strings)
  var Numbers := TCollections.CreateList<Integer>;

  // Dictionaries
  Settings := TCollections.CreateDictionary<string, string>;
end; // <-- Users and Settings are automatically released here
```

### 2. Ownership Management

"Ownership" is a crucial concept in Delphi. In Dext, it's smooth:

- **Object List**: By default, Dext assumes the list **owns** the objects.
- **Possession Transfer**: If you want the list to only reference external objects, use:

```delphi
// This list will NOT release objects on .Clear or when destroyed
Users := TCollections.CreateList<TUser>(False); 
```

### 3. LINQ and Functional Operations

Write cleaner and more expressive code.

```delphi
// Advanced filtering
var ActiveAdmins := Users
  .Where(function(U: TUser): Boolean
    begin
      Result := U.IsActive and (U.Role = 'Admin');
    end)
  .OrderBy(function(U: TUser): string
    begin
      Result := U.Name;
    end)
  .ToList;

// Quick checks
if Users.Any(function(U: TUser): Boolean begin Result := U.Age > 18 end) then
  Writeln('There are adults in the list');

// Transformation (Projection)
var Names: IList<string> := Users.Select<string>(
  function(U: TUser): string begin Result := U.Name end).ToList;
```

### 4. Expression Support (The Game Changer ✨)

Thanks to `Dext.Specifications`, you can filter lists using logical operators without writing verbose anonymous functions.

```delphi
uses 
  Dext.Collections, 
  Dext.Specifications.Expression;

// Direct filter by property (uses optimized internal RTTI)
var SpecificUsers := Users.Where(Prop('Status') = 'Active');
```

---

## 🏗️ Internal Architecture

### TSmartList<T>

The default implementation of `IList<T>`. It inherits from `TInterfacedObject`, allowing interface-managed lifecycle. Internally, it encapsulates the native `TList<T>` to maintain direct memory access performance while adding functional abstraction layers.

### TSmartDictionary<K, V>

`IDictionary<K,V>` implementation. It solves the issue of iterating over dictionaries and managing the lifetime of complex keys and values.

---

## 📊 Comparison Table

| Feature | System.Generics.Collections | Dext.Collections |
| :--- | :---: | :---: |
| **Lifecycle** | Manual (`.Free`) | Automatic (Interface) |
| **LINQ** | Limited / TEnumerable | Complete (`IList<T>`) |
| **Ownership** | Configured in Constructor | Native and Intelligent |
| **Fluent Syntax** | No | Yes |
| **Parameter Usage** | Leak Risk | 100% Safe |

---

## 📝 Best Practices

1. **Don't mix**: If you start using `IList<T>`, avoid converting to manual `TList<T>` to avoid losing reference tracking.
2. **Filters**: Use `.Where().ToList` if you need a physical copy of the data, or just iterate over `.Where()` for memory efficiency.
3. **Ownership**: When receiving a list from a service (like a Repository), assume you own the list, but the list manages the internal objects.

---

## 🚀 Next Steps

We are working on an additional **Lazy Evaluation** optimization and generic symbols reduction to further decrease compilation time in giant projects while keeping execution performance at the top.
