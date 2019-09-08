create sequence sq_pltap_results
start with 1
increment by 1
cycle
minvalue 1
maxvalue 999999999999;

create table pltap_results(
    id number(12),
    description varchar2(4000),
    output_text varchar2(4000),
    output_date timestamp default current_timestamp
);

create or replace trigger pltap_results_bi
   before insert on "W"."PLTAP_RESULTS"
   for each row
begin
   if inserting then
      if :NEW."ID" is null then
         select SQ_PLTAP_RESULTS.nextval into :NEW."ID" from dual;
      end if;
   end if;
end;