local ffi = require('ffi')
ffi.load("c")
ffi.load("m")
ffi.load("dl")

module("shm-ffi", package.seeall)

ffi.cdef[[

struct ipc_perm
{
	int __key;                      /* Key.  */
	unsigned int uid;                        /* Owner's user ID.  */
	unsigned int gid;                        /* Owner's group ID.  */
	unsigned int cuid;                       /* Creator's user ID.  */
	unsigned int cgid;                       /* Creator's group ID.  */
	unsigned short int mode;            /* Read/write permission.  */
	unsigned short int __pad1;
	unsigned short int __seq;           /* Sequence number.  */
	unsigned short int __pad2;
	unsigned long int __unused1;
	unsigned long int __unused2;
};


struct shmid_ds {
	struct ipc_perm		shm_perm;	
	int			shm_segsz;	
	long		shm_atime;	
	long		shm_dtime;	
	long		shm_ctime;	
	int		shm_cpid;	
	int		shm_lpid;	
	unsigned short		shm_nattch;	
	unsigned short 		shm_unused;	
	void 			*shm_unused2;	
	void			*shm_unused3;	
};


int shmctl(int shmid, int cmd, struct shmid_ds *buf);

int shmget(int key, size_t size, int shmflg);

void *shmat(int shmid, const void *shmaddr, int shmflg);

void perror(const char *s);

void *memcpy(void *dest, const void *src, size_t n);

void bzero(void *s, size_t n);


]]
ffi.cdef[[ typedef struct shm_msg { volatile int size; char data[1]; } shm_msg_t; ]]

local IPC_CREAT = 01000
local IPC_STAT = 2
local SHM_LIST = {}

function init(key, max)
	os.execute("ipcrm -M " ..  key)
	local shmid = ffi.C.shmget(key, max, IPC_CREAT)
	print(shmid)
	if shmid < 0 then
		ffi.C.perror("creat shm")
	end

	local addr = ffi.C.shmat(shmid, nil, 0)

	SHM_LIST[key] = {
		max = max,
		addr = addr,
		shmid = shmid,
	}
	ffi.C.bzero(addr, max)
end


function gain(key, have)
	if have then
		return SHM_LIST[key]
	else
		local shmid = ffi.C.shmget(key, 0, 0)
		if shmid == -1 then
			ffi.C.perror('')
			print(">>>>>>>>>>>>")
			os.exit(0)
		end
		print(shmid)
		if shmid < 0 then
			ffi.C.perror("get shm by key")
		end
		local shmds = ffi.new('struct shmid_ds [1]');
			print(">>>>>>>>>>>>")
		local flag = ffi.C.shmctl(shmid, IPC_STAT, shmds);
		local max = shmds[0].shm_segsz
			print(">>>>>>>>>>>>")
		print(max)
		local addr = ffi.C.shmat(shmid, nil, 0)
		return {
			max = max,
			addr = addr,
			shmid = shmid,
		}
	end
end

function push_C(key, have, data)
	if not data then
		return false
	end
	local info = gain(key, have)
	local slen = #data
	local mlen = info["max"] - ffi.sizeof("int * volatile")
	if slen > mlen then
		return false
	end
	local msg = ffi.new('shm_msg_t *[1]');
	local base = info["addr"]
	msg[0] = ffi.cast('shm_msg_t *', base);
	ffi.C.memcpy(msg[0].data, data, slen)
	--ffi.C.perror("str cpy")
	msg[0].size = slen
	return true
end


function push_L(key, have, data)
	if not data then
		return false
	end
	local info = gain(key, have)
	local slen = #data
	local mlen = info["max"] - ffi.sizeof("int * volatile")
	if slen > mlen then
		return false
	end
	local base = info["addr"]
	local iptr = ffi.cast('int * volatile', base)
	local buff = iptr + 1
	ffi.C.memcpy(buff, data, slen)
	--ffi.C.perror("str cpy")
	iptr[0] = slen
	return true
end

function pull_C(key, have)
	local msg = ffi.new('shm_msg_t *[1]');
	local info = gain(key, have)
	local base = info["addr"]
	msg[0] = ffi.cast('shm_msg_t *', base);
	--print('%p', msg[0]);
	return ffi.string(msg[0].data, msg[0].size)
end

function pull_L(key, have)
	local info = gain(key, have)
	local base = info["addr"]
	local iptr = ffi.cast('int * volatile', base)
	local size = iptr[0]
	local data = iptr + 1
	return ffi.string(data, size)
end

function zero(key, have)
	local info = gain(key, have)
	ffi.C.bzero(info["addr"], info["max"])
end

push = push_C
pull = pull_C
