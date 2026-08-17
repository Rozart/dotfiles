function pbcopy -d "Copy stdin to the client (Mac) clipboard"
    # clip-copy owns the tunnel, the OSC 52 fallback, and the arrival
    # notification. stdin streams straight through, bytes unchanged.
    ~/.local/bin/clip-copy $argv
end
