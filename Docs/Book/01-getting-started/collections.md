# 📦 Generic Collections

Dext includes a modern collection library designed to be lightweight, memory-safe, and rich in functional features (inspired by LINQ). It is the backbone of the framework, used by the ORM, Dependency Injection, and Web modules.

## Why not just use `TList<T>`?

Standard Delphi collections (`System.Generics.Collections`) have two main drawbacks in modern architectures:

1. **Manual Memory Management**: You must always remember to call `.Free`. This is error-prone when passing lists between services or layers.
2. **Verbosity**: Standard lists require loops for simple operations like filtering or checking existence.

## Key Features

- **Interface-based (`IList<T>`)**: Automatic lifecycle management via reference counting.
- **Safe Ownership**: Smart handling of objects. They are destroyed only when the list "owns" them.
- **LINQ Engine**: Built-in methods like `Where`, `Select`, `Any`, `First`, and `OrderBy`.
- **ORM Integration**: Filter your database results in-memory using the same specification patterns.

---

## Getting Started

### Creating Collections

Always refer to collections by their interface names. Use the `TCollections` factory to create instances.

```pascal
uses
  Dext.Collections;

var
  Users: IList<TUser>;
begin
  // Creates a list that OWNS the objects (will free them automatically)
  Users := TCollections.CreateObjectList<TUser>;

  // Creates a list of primitives (no ownership logic needed)
  var Numbers := TCollections.CreateList<Integer>;
end; // Both Users and Numbers are safely cleared from memory here.
```

### Basic Operations

```pascal
Users.Add(User1);
Users.AddRange([User2, User3]);

Writeln('Count: ', Users.Count);
Writeln('First User: ', Users[0].Name);

Users.Remove(User1);
Users.Clear; // Frees objects if OwnsObjects is True
```

---

## <a name="ownership"></a> Ownership & Memory Safety

Memory safety is a first-class citizen in Dext.

### Object Lists

When you use `TCollections.CreateObjectList<T>`, the list takes responsibility for the objects you add to it.

- When an object is removed, it is destroyed.
- When the list (interface) goes out of scope, all remaining objects are destroyed.

### Reference Lists

If you want to keep a list of objects but **not** destroy them (because they belong to another part of the app), use `CreateList<T>(False)`:

```pascal
// False means OwnsObjects = False
var RefList := TCollections.CreateList<TUser>(False);
```

---

## LINQ & Functional Logic

Dext Collections bring the power of functional programming to Delphi.

### Filtering and Searching

```pascal
// Find all active admins
var Admins := Users.Where(function(U: TUser): Boolean
  begin
    Result := U.IsActive and (U.Role = 'Admin');
  end).ToList;

// Check if any user is from London
if Users.Any(function(U: TUser): Boolean begin Result := U.City = 'London' end) then
  Writeln('Londoners found!');

// Get the first match or nil
var FirstVip := Users.FirstOrDefault(function(U: TUser): Boolean begin Result := U.IsVip end);
```

### Projections (Transforming)

```pascal
// Get a list of just the names (string list)
var Names := Users.Select<string>(function(U: TUser): string
  begin
    Result := U.Name;
  end).ToList;
```

---

## Performance Tip

Methods like `.Where()` and `.Select()` return lazy iterators by default. They don't copy the whole list immediately. If you just need to loop over the result, don't call `.ToList`. Use `.ToList` only when you need to store the result for later or return it from a method.

```pascal
// Efficient: No copy made
for var Admin in Users.Where(IsAdmin) do
  Process(Admin);

// Required: Result is stored/returned
Result := Users.Where(IsAdmin).ToList;
```
