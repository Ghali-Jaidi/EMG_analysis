function m = keep_long_runs(mask, minLen)
    mask = mask(:) ~= 0;
    d = diff([false; mask; false]);
    starts = find(d==1);
    ends   = find(d==-1)-1;
    lens   = ends - starts + 1;
    keep = lens >= minLen;
    m = false(size(mask));
    for k = find(keep).'
        m(starts(k):ends(k)) = true;
    end
end