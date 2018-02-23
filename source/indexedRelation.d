module indexedRelation;

import std.functional: unaryFun;
import std.typecons: Nullable, Tuple, nullable;

version (unittest) {
    import std.exception: assertThrown;
}

/// A bag of records with efficient lookup on multiple independent keys.
public class IndexedRelation(Record, Indices...) {
    private Record[] records;
    private Tuple!Indices indices;

    public this() {
        static foreach (i; 0 .. Indices.length) {
            indices[i] = new Indices[i];
        }
    }

    public void insert(Record record) {
        records ~= [record];
        static foreach (i; 0 .. Indices.length) {
            indices[i].insert(record);
        }
    }

    public auto lookup(int i)(Indices[i].Key key) {
        return indices[i].lookup(key);
    }
}

/// An index based on a hash table. Allows multiple records with the same key.
public class HashTableIndex(Record, string KeyString) {
    private alias KeyFunction = unaryFun!KeyString;
    public alias Key = typeof(KeyFunction(Record.init));

    private Record[][Key] records;

    public void insert(Record record) {
        records[KeyFunction(record)] ~= [record];
    }

    public Record[] lookup(Key key) {
        if (key !in records) return [];
        return records[key];
    }
}

/// An index based on a hash table. Prohibits multiple records with the same
/// key.
public class UniqueHashTableIndex(Record, string KeyString) {
    private alias KeyFunction = unaryFun!KeyString;
    public alias Key = typeof(KeyFunction(Record.init));

    private Record[Key] records;

    public void insert(Record record) {
        auto key = KeyFunction(record);
        if (key in records) {
            throw new Exception("Key already present in unique index");
        }
        records[key] = record;
    }

    public Nullable!Record lookup(Key key) {
        if (key !in records) return Nullable!Record.init;
        return records[key].nullable;
    }
}

unittest {
    struct Employee {
        public ulong id;
        public string firstName;
        public string lastName;
        public ulong salary;
    }

    auto employee1 = Employee(1, "John", "Backus", 1000);
    auto employee2 = Employee(2, "Rob", "Pike", 1100);
    auto employee3 = Employee(3, "Walter", "Bright", 1200);

    auto employees = new IndexedRelation!(
        Employee,
        UniqueHashTableIndex!(Employee, "a.id"),
        HashTableIndex!(Employee, "a.firstName"),
        HashTableIndex!(Employee, "a.firstName.toUpper")
    );

    employees.insert(employee1);
    employees.insert(employee2);
    employees.insert(employee3);
    assertThrown(employees.insert(employee1));

    assert(employees.lookup!0(1) == employee1.nullable);
    assert(employees.lookup!1("Rob") == [employee2]);
    assert(employees.lookup!2("WALTER") == [employee3]);

    assert(employees.lookup!0(4) == Nullable!Employee.init);
    assert(employees.lookup!1("Guido") == []);
    assert(employees.lookup!2("BJARNE") == []);
}
