local modename = "queue"
local Queue = {}
_G[modename] = Queue
package.loaded[modename] = Queue


function Queue:new( capacity )
	local queue = { 
			_first = 0,			--第一个有效数据的下标
			_last = -1,			--最后一个有效数据的下标
			_counter = 0,			--有效数据的总个数
			_maxindex = capacity,		--允许保存数据的最大个数
			_value = {}			--保存数据的表
		};
	setmetatable(queue, self);
	self.__index = self;
	return queue;
end

--添加一个数据到队列尾
function Queue:push( value )
	if self._counter >= self._maxindex then
		print(string.format("no more space in queue"));
		return false;
	end

	self._last = (self._last + 1) % self._maxindex;
	self._value[self._last] = value;
	self._counter = self._counter + 1;

	return true;
end

--从队列头取出一个数据
function Queue:pull( ... )
	if self._counter == 0 then
		print(string.format("queue is empty"));
		return nil;
	end

	local value = self._value[self._first]
	self._value[self._first] = nil;
	self._first = (self._first + 1) % self._maxindex;
	self._counter = self._counter - 1;

	return value;
end

--释放队列里面的数据[destroycb:销毁队列节点中的数据函数，可以为nil]
function Queue:free( destroycb )
	while self._counter > 0 do
		if destroycb then
			local ok ;
			ok = pcall(destroycb, self._value[self._first]);
			if not ok then
				print("call destroycb function failed");
				break;
			end
		end
		self._value[self._first]= nil;
		self._first =(self._first + 1) % self._maxindex;
		self._counter = self._counter - 1;
	end
	print("Free Queue done");
end
