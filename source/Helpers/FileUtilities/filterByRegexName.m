function strlist = filterByRegexName(strlist,regex)
    select = regexp(strlist,regex,'match','forcecelloutput','ignorecase');
    strlist = strlist(cellfun(@(x)(~isempty(x)),select));
end

