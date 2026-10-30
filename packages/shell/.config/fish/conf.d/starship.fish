if status is-interactive
    and test "$TERM" != "linux"
    and test "$TERM" != "dumb"
    
    starship init fish | source
end
