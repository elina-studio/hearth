' Queue commands for the player (included by MusicPlayer). Returns true when handled.
' queueJump {i}, queueMove {from, to}, queueRemove {i}, queueClear, queueShuffleRest
function queueCommand(c as object) as boolean
    cmd = c.cmd
    q = m.top.queue
    if q = invalid then q = []
    n = q.count()
    cur = m.top.index
    if cmd = "queueJump"
        if c.i >= 0 and c.i < n then playIndex(c.i)
    else if cmd = "queueMove"
        f = c.from
        t = c.to
        if f < 0 or f >= n or t < 0 or t >= n or f = t then return true
        out = []
        for each x in q
            out.push(x)
        end for
        item = out[f]
        out.delete(f)
        out.insert(t, item)
        ni = cur
        if f = cur
            ni = t
        else if f < cur and t >= cur
            ni = cur - 1
        else if f > cur and t <= cur
            ni = cur + 1
        end if
        m.top.queue = out
        m.top.index = ni
        m.original = invalid
    else if cmd = "queueRemove"
        r = c.i
        if r < 0 or r >= n or r = cur then return true
        out = []
        for i = 0 to n - 1
            if i <> r then out.push(q[i])
        end for
        m.top.queue = out
        if r < cur then m.top.index = cur - 1
    else if cmd = "queueClear"
        if n < 2 then return true
        m.top.queue = [q[cur]]
        m.top.index = 0
        m.original = invalid
        say("Queue cleared")
    else if cmd = "queueShuffleRest"
        if cur >= n - 2 then return true
        rest = []
        for i = cur + 1 to n - 1
            rest.push(q[i])
        end for
        rest = shuffled(rest)
        out = []
        for i = 0 to cur
            out.push(q[i])
        end for
        out.append(rest)
        m.top.queue = out
        say("Shuffled what's left")
    else
        return false
    end if
    return true
end function
