local rregexp = require "rspamd_regexp"
local rlogger = require "rspamd_logger"
local rhash   = require "rspamd_cryptobox_hash"
local rutil   = require "lua_util"
local rip     = require "rspamd_ip"

local ABUSIX_API_KEY = os.getenv("ABUSIX_API_KEY");

-- Comment any of the following lines out to disable the lookups
-- NOTE: if you run rbldnsd yourself and rsync the data then you might need to modify these.
local check_shorturls_dns      = '.' .. ABUSIX_API_KEY .. '.shorthash.mail.abusix.zone.'
local check_diskurls_dns       = '.' .. ABUSIX_API_KEY .. '.diskhash.mail.abusix.zone.'
local check_web_submission_dns = '.' .. ABUSIX_API_KEY .. '.combined.mail.abusix.zone.'
local check_btc_dns            = '.' .. ABUSIX_API_KEY .. '.btc-wallets.mail-beta.abusix.zone.'

local re_short_path = rregexp.create_cached('/^(?!(?:[a-z]+|[A-Z]+|[0-9]+)$)[a-zA-Z0-9]{3,11}$/')

local check_shorturls_cb = function (task)
    -- Disable checks if no DNS namespace is set-up
    if not (check_shorturls_dns) then return false end

    local function find_short_urls (url)
        local path = url:get_path();
        if (re_short_path:match(path)) then
            return true
        end
    end
    local shorturls = rutil.extract_specific_urls({
        task = task,
        limit = 5,
        prefix = 'shorturls',
        filter = find_short_urls
    });

    if (not shorturls) then return false end

    local r = task:get_resolver()

    for _, url in pairs(shorturls) do
        -- Normalize
        local surl = url:get_host():lower() .. '/' .. url:get_path()
        local surl_hash = rhash.create_specific('sha1', surl):hex()
        local lookup = surl_hash .. check_shorturls_dns
        local function dns_cb(_,_,results,err)
            if (not results) then return false end
            if (tostring(results[1]) == '127.0.3.1') then
                rlogger.errx('found URL %s (%s) in Short URL blacklist', surl, surl_hash)
                return task:insert_result('RBL_AMI_SHORTURL', 1.0, surl);
            end
        end
        r:resolve_a({ task = task, name = lookup , callback = dns_cb })
    end
end

local check_shorturls = rspamd_config:register_symbol({
    name = "RBL_AMI_SHORTURL",
    type = "callback",
    callback = check_shorturls_cb
});

local re_disk_urls = rregexp.create_cached('/^(?:drive\\.google\\.com$|yadi\\.sk$|disk\\.yandex\\.)/')

local check_diskurls_cb = function (task)
    -- Disable checks if no DNS namespace is set-up
    if not (check_diskurls_dns) then return false end

    local function find_disk_urls (url)
        local host = url:get_host():lower();
        if (re_disk_urls:match(host)) then
            return true
        end
    end
    local diskurls = rutil.extract_specific_urls({
        task = task,
        limit = 5,
        prefix = 'diskurls',
        filter = find_disk_urls
    });

    if (not diskurls) then return false end

    local r = task:get_resolver()

    for _, url in pairs(diskurls) do
        -- Normalize
        local durl = url:get_host():lower() .. '/' .. url:get_path()
        local durl_hash = rhash.create_specific('sha1', durl):hex()
        local lookup = durl_hash .. check_diskurls_dns
        local function dns_cb(_,_,results,err)
            if (not results) then return false end
            if (tostring(results[1]) == '127.0.3.2') then
                rlogger.errx('found URL %s (%s) in Disk URL blacklist', durl, durl_hash)
                return task:insert_result('RBL_AMI_DISKURL', 1.0, durl);
            end
        end
        r:resolve_a({ task = task, name = lookup , callback = dns_cb })
    end
end

local check_diskurls = rspamd_config:register_symbol({
    name = "RBL_AMI_DISKURL",
    type = "callback",
    callback = check_diskurls_cb
});

local re_web_submission_ips = rregexp.create_cached('/for (.+)$/')

local check_web_submission_ips_cb = function (task)
    -- Disable checks if no DNS namespace is set-up
    if not (check_web_submission_dns) then return false end

    local ips
    if (task:has_header('x-php-script')) then
        local h = task:get_header('x-php-script')
        local m = re_web_submission_ips:search(h, false, true)
        if (m and m[1] and m[1][2]) then
            ips = m[1][2]
        end
    end

    if (task:has_header('http-posting-client')) then
        if (ips) then
            ips = ips .. ' ' .. task:get_header('http-posting-client')
        else
            ips = task:get_header('http-posting-client')
        end
    end

    if not (ips) then return false end

    local dedup = {}
    for ip in string.gmatch(ips, '([^, ]+)') do
        dedup[ip] = true;
    end

    local c = task:get_from_ip()
    local cip
    if (c) then
        cip = c:to_string()
    end

    local r = task:get_resolver()

    for k, v in pairs(dedup) do
        -- Exclude IPs that match the From IP
        if (k ~= cip) then
            local ip4 = rip.from_string(k)
            if not (ip4) then goto continue end
        local lookup = table.concat(ip4:inversed_str_octets(), '.') .. check_web_submission_dns
            local function dns_cb(_,_,results,err)
        rlogger.errx('lookup=%s, results=%s, err=%s', lookup, results, err)
                if (not results) then return false end 
                for _, result in ipairs(results) do 
                    if (tostring(result) == '127.0.0.4') then
                        return task:insert_result('RBL_AMI_BLACK_HTTP', 1.0, k);
                end
        end
            end
            r:resolve_a({ task = task, name = lookup , callback = dns_cb })
        ::continue::
    end
    end
end

local check_diskurls = rspamd_config:register_symbol({
    name = "RBL_AMI_BLACK_HTTP",
    type = "callback",
    callback = check_web_submission_ips_cb
});

local btc_wallet_re = rregexp.create_cached('/(?:^|\\s)((?:[13]|bc1)[A-HJ-NP-Za-km-z1-9]{27,34})(?:\\s|$)/')

local check_btc_cb = function (task)
    -- Disable checks if no DNS namespace is set-up
    if not (check_btc_dns) then return false end

    local parts = task:get_text_parts()
    if not parts then return false end
    local r = task:get_resolver()
    for _, part in ipairs(parts) do
        local words = part:get_words('raw')
        for _, word in ipairs(words) do
            local match = btc_wallet_re:match(word)
            if match then
                local btc_hash = rhash.create_specific('sha1', word):hex()
                local lookup = btc_hash .. check_btc_dns
                local function dns_cb(_,_,results,err)
                    if (not results) then return false end
                    if (tostring(results[1]) == '127.0.4.1') then
                        rlogger.errx('found BTC wallet %s (%s) in BTC Wallet blacklist', word, btc_hash)
                        return task:insert_result('RBL_AMI_BTC', 1.0, word);
                    end
                end
                r:resolve_a({ task = task, name = lookup , callback = dns_cb, forced = true })
            end
        end
    end
end

local check_btc = rspamd_config:register_symbol({
    name = "RBL_AMI_BTC",
    type = "callback",
    callback = check_btc_cb
});
