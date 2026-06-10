function emacode
    emacs -nw --eval "(run-with-idle-timer 1 nil #'my/emacode)"
end
