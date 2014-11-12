--[[

Copyright 2014 The Luvit Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

--]]
local uv = require('uv')
local fs = exports

local function noop(err)
  if err then print("Unhandled callback error", err) end
end

local function adapt(c, fn, ...)
  local nargs = select('#', ...)
  local args = {...}
  -- No continuation defaults to noop callback
  if not c then c = noop end
  local t = type(c)
  if t == 'function' then
    args[nargs + 1] = c
    return fn(unpack(args))
  elseif t ~= 'thread' then
    error("Illegal continuation type " .. t)
  end
  local err, data, waiting
  args[nargs + 1] = function (err, ...)
    if waiting then
      if err then
        coroutine.resume(c, nil, err)
      else
        coroutine.resume(c, ...)
      end
    else
      error, data = err, {...}
      c = nil
    end
  end
  fn(unpack(args))
  if c then
    waiting = true
    return coroutine.yield(c)
  elseif err then
    return nil, err
  else
    return unpack(data)
  end
end


function fs.close(fd, callback)
  return adapt(callback, uv.fs_close, fd)
end
function fs.closeSync(fd)
  return uv.fs_close(fd)
end

function fs.open(path, flags, mode, callback)
  local ft = type(flags)
  local mt = type(mode)
  -- (path, callback)
  if (ft == 'function' or ft == 'thread') and
     (mode == nil and callback == nil) then
    callback, flags = flags, nil
  -- (path, flags, callback)
  elseif (mt == 'function' or mt == 'thread') and
         (callback == nil) then
    callback, mode = mode, nil
  end
  -- Default flags to 'r'
  if flags == nil then
    flags = 'r'
  end
  -- Default mode to 0666
  if mode == nil then
    mode = 438 -- 0666
  -- Assume strings are octal numbers
  elseif mt == 'string' then
    mode = tonumber(mode, 8)
  end
  return adapt(callback, uv.fs_open, path, flags, mode)
end
function fs.openSync(path, flags, mode)
  if flags == nil then
    flags = "r"
  end
  if mode == nil then
    mode = 438 --  0666
  elseif type(mode) == "string" then
    mode = tonumber(mode, 8)
  end
  return uv.fs_open(path, flags, mode)
end
function fs.read(fd, size, offset, callback)
  local st = type(size)
  local ot = type(offset)
  if (st == 'function' or st == 'thread') and
     (offset == nil and callback == nil) then
    callback, size = size, nil
  elseif (ot == 'function' or ot == 'thread') and
         (callback == nil) then
    callback, offset = offset, nil
  end
  if size == nil then
    size = 4096
  end
  if offset == nil then
    -- TODO: allow nil in luv for append position
    offset = 0
  end
  return adapt(callback, uv.fs_read, fd, size, offset)
end
function fs.readSync(fd, size, offset)
  if size == nil then
    size = 4096
  end
  if offset == nil then
    -- TODO: allow nil in luv for append position
    offset = 0
  end
  return uv.fs_read(fd, size, offset)
end
function fs.unlink(path, callback)
  return adapt(callback, uv.fs_unlink, path)
end
function fs.unlinkSync(path)
  return uv.fs_unlink(path)
end
function fs.write(fd, data, offset, callback)
  local ot = type(offset)
  if (ot == 'function' or ot == 'thread') and
     (callback == nil) then
    callback, offset = offset, nil
  end
  if offset == nil then
    -- TODO: allow nil in luv for append position
    offset = 0
  end
  return adapt(callback, uv.fs_write, fd, data, offset)
end
function fs.writeSync(fd, data, offset)
  if offset == nil then
    -- TODO: allow nil in luv for append position
    offset = 0
  end
  return uv.fs_write(fd, data, offset)
end
function fs.mkdir(path, mode, callback)
  local mt = type(mode)
  if (mt == 'function' or mt == 'thread') and
     (callback == nil) then
    callback, mode = mode, nil
  end
  if mode == nil then
    mode = 511 -- 0777
  end
  return adapt(callback, uv.fs_mkdir, path, mode)
end
function fs.mkdirSync(path, mode)
  if mode == nil then
    mode = 511
  end
  return uv.fs_mkdir(path, mode)
end
function fs.mkdtemp(template, callback)
  return adapt(callback, uv.fs_mkdtemp, template)
end
function fs.mkdtempSync(template)
  return uv.fs_mkdtemp(template)
end
function fs.rmdir(path, callback)
  return adapt(callback, uv.fs_rmdir, path)
end
function fs.rmdirSync(path)
  return uv.fs_rmdir(path)
end
local function readdir(path, callback)
  uv.fs_scandir(path, function (err, req)
    if err then return callback(err) end
    local files = {}
    local i = 1
    while true do
      local ent = uv.fs_scandir_next(req)
      if not ent then break end
      files[i] = ent.name
      i = i + 1
    end
    callback(nil, files)
  end)
end
function fs.readdir(path, callback)
  return adapt(callback, readdir, path)
end
function fs.readdirSync(path)
  local req = uv.fs_scandir(path)
  local files = {}
  local i = 1
  while true do
    local ent = uv.fs_scandir_next(req)
    if not ent then break end
    files[i] = ent.name
    i = i + 1
  end
  return files
end
local function scandir(path, callback)
  uv.fs_scandir(path, function (err, req)
    if err then return callback(err) end
    callback(nil, function ()
      local ent = uv.fs_scandir_next(req)
      if ent then
        return ent.name, ent.type
      end
    end)
  end)
end
function fs.scandir(path, callback)
  return adapt(callback, scandir, path)
end
function fs.scandirSync(path)
  local req = uv.fs_scandir(path)
  return function ()
    local ent = uv.fs_scandir_next(req)
    if ent then
      return ent.name, ent.type
    end
  end
end
function fs.stat(path, callback)
  return adapt(callback, uv.fs_stat, path)
end
function fs.statSync(path)
  return uv.fs_stat(path)
end
function fs.fstat(fd, callback)
  return adapt(callback, uv.fs_fstat, fd)
end
function fs.fstatSync(fd)
  return uv.fs_fstat(fd)
end
function fs.lstat(path, callback)
  return adapt(callback, uv.fs_lstat, path)
end
function fs.lstatSync(path)
  return uv.fs_lstat(path)
end
function fs.rename(path, newPath, callback)
  return adapt(callback, uv.fs_rename, path, newPath)
end
function fs.renameSync(path, newPath)
  return uv.fs_rename(path, newPath)
end
function fs.fsync(fd, callback)
  return adapt(callback, uv.fs_fsync, fd)
end
function fs.fsyncSync(fd)
  return uv.fs_fsync(fd)
end
function fs.fdatasync(fd, callback)
  return adapt(callback, uv.fs_fdatasync, fd)
end
function fs.fdatasyncSync(fd)
  return uv.fs_fdatasync(fd)
end
function fs.ftruncate(fd, offset, callback)
  local ot = type(offset)
  if (ot == 'function' or ot == 'thread') and
     (callback == nil) then
    callback, offset = offset, nil
  end
  if offset == nil then
    offset = 0
  end
  return adapt(callback, uv.fs_ftruncate, fd, offset)
end
function fs.ftruncateSync(fd, offset)
  if offset == nil then
    offset = 0
  end
  return uv.fs_ftruncate(fd, offset)
end
function fs.sendfile(outFd, inFd, offset, length, callback)
  return adapt(callback, uv.fs_sendfile, outFd, inFd, offset, length)
end
function fs.sendfileSync(outFd, inFd, offset, length)
  return uv.fs_sendfile(outFd, inFd, offset, length)
end
function fs.access(path, flags, callback)
  local ft = type(flags)
  if (ft == 'function' or ft == 'thread') and
     (callback == nil) then
    callback, flags = flags, nil
  end
  if flags == nil then
    flags = 0
  end
  return adapt(callback, uv.fs_access, path, flags)
end
function fs.accessSync(path, flags)
  if flags == nil then
    flags = 0
  end
  return uv.fs_access(path, flags)
end
function fs.chmod(path, mode, callback)
  return adapt(callback, uv.fs_chmod, path, mode)
end
function fs.chmodSync(path, mode)
  return uv.fs_chmod(path, mode)
end
function fs.fchmod(fd, mode, callback)
  return adapt(callback, uv.fs_fchmod, fd, mode)
end
function fs.fchmodSync(fd, mode)
  return uv.fs_fchmod(fd, mode)
end
function fs.utime(path, atime, mtime, callback)
  return adapt(callback, uv.fs_utime, path, atime, mtime)
end
function fs.utimeSync(path, atime, mtime)
  return uv.fs_utime(path, atime, mtime)
end
function fs.futime(fd, atime, mtime, callback)
  return adapt(callback, uv.fs_futime, fd, atime, mtime)
end
function fs.futimeSync(fd, atime, mtime)
  return uv.fs_futime(fd, atime, mtime)
end
function fs.link(path, newPath, callback)
  return adapt(callback, uv.fs_link, path, newPath)
end
function fs.linkSync(path, newPath)
  return uv.fs_link(path, newPath)
end
function fs.symlink(path, newPath, options, callback)
  local ot = type(options)
  if (ot == 'function' or ot == 'thread') and
     (callback == nil) then
    callback, options = options, nil
  end
  return adapt(callback, uv.fs_symlink, path, newPath, options)
end
function fs.symlinkSync(path, newPath, options)
  return uv.fs_symlink(path, newPath, options)
end
function fs.readlink(path, callback)
  return adapt(callback, uv.fs_readlink, path)
end
function fs.readlinkSync(path)
  return uv.fs_readlink(path)
end
function fs.chown(path, uid, gid, callback)
  return adapt(callback, uv.fs_chown, path, uid, gid)
end
function fs.chownSync(path, uid, gid)
  return uv.fs_chown(path, uid, gid)
end
function fs.fchown(fd, uid, gid, callback)
  return adapt(callback, uv.fs_fchown, fd, uid, gid)
end
function fs.fchownSync(fd, uid, gid)
  return uv.fs_fchown(fd, uid, gid)
end
local function readFile(path, callback)
  local fd, onStat, onRead
  fs.open(path, "r", 0600, function (err, result)
    if err then return callback(err) end
    fd = result
    fs.fstat(fd, onStat)
  end)
  function onStat(err, stat)
    if err then return onRead(err) end
    fs.read(fd, stat.size, 0, onRead)
  end
  function onRead(err, chunk)
    fs.close(fd)
    return callback(err, chunk)
  end
end
function fs.readFile(path, callback)
  return adapt(callback, readFile, path)
end
function fs.readFileSync(path)
  local fd = assert(fs.openSync(path, "r", 0600))
  local stat, err, chunk
  stat, err = fs.fstatSync(fd)
  if stat then
    chunk, err = fs.readSync(fd, stat.size)
  end
  fs.close(fd)
  if err then
    error(err)
  else
    return chunk
  end
end