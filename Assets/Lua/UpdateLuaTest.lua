local hotfix = xlua.hotfix
require("mobdebug").start()

function Description()    
    local testNum = 0
    self:Print2()
    print(testNum)
    print(self.test)
end

--需要熱更新配置
hotfix(CS.UpdateLuaTest, 
  {Description = Description}
)