# Unauth Retrier

This plugin auto retries players without steam authentication, to prevent them breaking it for the entire server.

Recently there has been widespread Steam authentication issues on CS:GO servers, not just delayed auths, but sometimes complete breakage of auth for all new connections to a server. This appears to be somehow caused by the auth for a select few players failing and "blocking" the rest from even running. This plugin attempts to stop that from happening.

This still needs some more live testing time to guarantee effectiveness & find the best cvar values, but early results seem very promising so far. There may also still be issues such as retry loops, please report any problems and include connection & plugin logs.