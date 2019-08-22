# pltap
TAP-like unit testing package for PL/SQL

## Install

First, run pltap_ddl.sql. After that compile pltap.pks and pltap.pkb files. That's all.

## Examples


### Easy mode

```sql
begin
    pltap.start_test;
    
    pltap.eq(2, 3, '2 = 3');
    pltap.eq('John Doe', 'NotJohnDoe', '"John Doe" is equal to "NotJohnDoe"');
    pltap.eq(to_date('1981.01.23', 'yyyy.mm.dd'), to_date('1981.01.23', 'yyyy.mm.dd'), 'Dates are equal');
    pltap.ok(Sysdate > sysdate -1, 'Today is later than yesterday');
       
    pltap.end_test;
end;
```

This code produce output (via dbms_output.put_line):
```
not ok: 1 2 = 3
# Expected:3
# Got: 2
not ok: 2 "John Doe" is equal to "NotJohnDoe"
# Expected: 'NotJohnDoe'
# Got: 'John Doe'
ok 3 Dates are equal
ok 4 Today is later than yesterday
FAILED: 1,2
Failed 2/4 50% ok
0 hours 0 minutes ,001 seconds
```

### Test function

```sql
declare
    /*
    || Return true for all non-zero
    || numbers.
    */
    function bool(
        val number
    ) return boolean
    is
        res boolean;
    begin
        return (val <> 0);
    end;

begin
    pltap.start_test;
    
    -- #bt-1: Pass non-zero number
    -- Expected result: Function return True
    pltap.ok(bool(1), 'bt-1: True for positive number');
    
    -- #bt-2: Pass negative number
    -- Expected result: True
    pltap.ok(bool(-20), 'bt-2: True for negative number');
    
    -- #bt-3: Pass zero
    -- Expected result: False
    -- Next 2 examples are the same
    pltap.ok(not bool(0), 'bt-3: False for zero');
    pltap.ok(bool(0) = False,  'bt-3: False for zero'); 
    
    -- #bt-4: What if I pass NULL? I think function must
    -- return false.
    pltap.ok(bool(null) = False, 'False for null');
    
    pltap.end_test;
end;
```

Result:

```
ok 1 bt-1: True for positive number
ok 2 bt-2: True for negative number
ok 3 bt-3: False for zero
ok 4 bt-3: False for zero
not ok: 5 False for null
FAILED: 5
Failed 1/5 80% ok
0 hours 0 minutes ,001 seconds
```
