const c = @cImport({
    @cInclude("unistd.h");
});

pub const getpid = c.getpid;
