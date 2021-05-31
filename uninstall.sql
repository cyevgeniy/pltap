begin
	begin execute immediate 'drop sequence sq_pltap_results'; exception when others then null; end;
	begin execute immediate 'drop table pltap_results'; exception when others then null; end;
	begin execute immediate 'drop package pltap'; exception when others then null; end;
end;
/

show err