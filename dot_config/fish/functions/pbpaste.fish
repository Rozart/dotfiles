function pbpaste -d "Print the client's clipboard via the ssh pbpaste tunnel"
    # Served by the Mac's pbpaste-server launchd agent through ssh RemoteForward.
    nc -w 1 127.0.0.1 2489
end
