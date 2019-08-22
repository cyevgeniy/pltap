# pltap
TAP-like unit testing package for PL/SQL

## Install

First, run pltap_ddl.sql. After that compile pltap.pks and pltap.pkb files. That's all.

## Examples

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
