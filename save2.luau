-- ============================================================
-- MODEL & TEXTURE SAVER - No Scripts
-- Saves: Parts, Meshes, Textures, Colors, Positions, Sizes
-- Skips: All Scripts, UI, CoreGui
-- ============================================================

-- ============================================================
-- BASE64 ENCODE (self-contained)
-- ============================================================
local function base64encode(data)
    local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    local result = {}
    local data_len = #data
    local padding = 0
    
    for i = 1, data_len, 3 do
        local a, b, c = string.byte(data, i, i+2)
        local n = (a or 0) * 0x10000 + (b or 0) * 0x100 + (c or 0)
        
        result[#result+1] = b64chars:sub(math.floor(n/0x40000) % 64 + 1, math.floor(n/0x40000) % 64 + 1)
        result[#result+1] = b64chars:sub(math.floor(n/0x1000) % 64 + 1, math.floor(n/0x1000) % 64 + 1)
        result[#result+1] = b64chars:sub(math.floor(n/0x40) % 64 + 1, math.floor(n/0x40) % 64 + 1)
        result[#result+1] = b64chars:sub(n % 64 + 1, n % 64 + 1)
        
        if not b then padding = 1 end
        if not c then padding = 2 end
    end
    
    if padding > 0 then
        result[#result] = string.sub(result[#result], 1, 4 - padding)
        result[#result] = result[#result] .. string.rep('=', padding)
    end
    
    return table.concat(result)
end

-- ============================================================
-- SCRIPT SKIP LIST
-- ============================================================
local SCRIPT_CLASSES = {
    "Script",
    "LocalScript",
    "ModuleScript",
    "RemoteEvent",
    "RemoteFunction",
    "BindableEvent",
    "BindableFunction",
}

local IGNORE_CLASSES = {
    "CoreGui",
    "RobloxGui",
    "ScreenGui",
    "Frame",
    "TextLabel",
    "TextButton",
    "ImageLabel",
    "ImageButton",
    "ScrollingFrame",
    "UIGridLayout",
    "UIListLayout",
    "UIPadding",
    "UIStroke",
    "UICorner",
    "CanvasGroup",
    "ViewportFrame",
}

local VISUAL_PROPERTIES = {
    -- BasePart properties
    "Size", "CFrame", "Transparency", "Color", "Material", "BrickColor", 
    "Anchored", "CanCollide", "Locked", "Position", "Orientation",
    
    -- MeshPart properties
    "MeshId", "TextureId", "MeshSize", "RenderFidelity", "CollisionFidelity",
    
    -- Part properties
    "Shape", "BottomSurface", "TopSurface", "FrontSurface", "BackSurface", 
    "LeftSurface", "RightSurface",
    
    -- SpecialPart properties
    "Reflectance", "Elasticity", "Friction", "Roughness", "Metallic",
    
    -- MaterialVariant
    "MaterialVariant",
    
    -- Union and CSG
    "SolidModel",
}

-- ============================================================
-- MAIN SAVE FUNCTION
-- ============================================================
local function SaveModelAndTextures(workspace_obj, file_name)
    workspace_obj = workspace_obj or game.Workspace
    file_name = file_name or "saved_models_" .. os.time()
    
    print("Starting Model & Texture Save...")
    print("Source:", workspace_obj:GetFullName())
    print("File:", file_name)
    
    local referents = {}
    local ref_count = 0
    
    local function get_ref(instance)
        local ref = referents[instance]
        if not ref then
            ref_count = ref_count + 1
            ref = string.format("REF%08X", ref_count)
            referents[instance] = ref
        end
        return ref
    end
    
    local function should_save_instance(instance)
        local class_name = instance.ClassName
        
        -- Skip scripts
        for _, script_class in ipairs(SCRIPT_CLASSES) do
            if class_name == script_class then
                return false
            end
        end
        
        -- Skip UI
        for _, ignore_class in ipairs(IGNORE_CLASSES) do
            if class_name == ignore_class then
                return false
            end
        end
        
        -- Skip if not Archivable
        if not instance.Archivable then
            return false
        end
        
        return true
    end
    
    local function get_visual_properties(instance)
        local props = {}
        
        for _, prop_name in ipairs(VISUAL_PROPERTIES) do
            local success, value = pcall(function()
                return instance[prop_name]
            end)
            if success and value ~= nil then
                props[prop_name] = value
            end
        end
        
        -- Special case: If MeshPart has MeshId, include it properly
        if instance:IsA("MeshPart") then
            local mesh_id = instance.MeshId
            if mesh_id and mesh_id ~= "" then
                props["MeshId"] = mesh_id
            end
            local texture_id = instance.TextureId
            if texture_id and texture_id ~= "" then
                props["TextureId"] = texture_id
            end
        end
        
        -- Special case: If Part has BrickColor
        if instance:IsA("BasePart") then
            local color = instance.Color
            local material = instance.Material
            if color then props["Color"] = color end
            if material then props["Material"] = material end
        end
        
        return props
    end
    
    local function escape_xml(str)
        if not str then return "" end
        return str:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&#39;")
    end
    
    local function serialize_value(value)
        if value == nil then
            return "null"
        end
        
        local t = typeof(value)
        
        if t == "string" then
            return escape_xml(value)
        elseif t == "number" then
            return tostring(value)
        elseif t == "boolean" then
            return value and "true" or "false"
        elseif t == "Color3" then
            return string.format("<R>%.3f</R><G>%.3f</G><B>%.3f</B>", value.R, value.G, value.B)
        elseif t == "Vector3" then
            return string.format("<X>%.3f</X><Y>%.3f</Y><Z>%.3f</Z>", value.X, value.Y, value.Z)
        elseif t == "CFrame" then
            local x, y, z = value.Position.X, value.Position.Y, value.Position.Z
            local r00, r01, r02, r10, r11, r12, r20, r21, r22 = value:GetComponents()
            return string.format(
                "<X>%.3f</X><Y>%.3f</Y><Z>%.3f</Z><R00>%.3f</R00><R01>%.3f</R01><R02>%.3f</R02><R10>%.3f</R10><R11>%.3f</R11><R12>%.3f</R12><R20>%.3f</R20><R21>%.3f</R21><R22>%.3f</R22>",
                x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22
            )
        elseif t == "BrickColor" then
            return tostring(value.Number)
        elseif t == "EnumItem" then
            return tostring(value.Value)
        elseif t == "Instance" then
            if should_save_instance(value) then
                return get_ref(value)
            end
            return "null"
        else
            return tostring(value)
        end
    end
    
    local function get_property_tag(value)
        local t = typeof(value)
        if t == "string" then
            return "string"
        elseif t == "number" then
            return "float"
        elseif t == "boolean" then
            return "bool"
        elseif t == "Color3" then
            return "Color3"
        elseif t == "Vector3" then
            return "Vector3"
        elseif t == "CFrame" then
            return "CFrame"
        elseif t == "BrickColor" then
            return "BrickColor"
        elseif t == "EnumItem" then
            return "token"
        elseif t == "Instance" then
            return "Ref"
        else
            return "string"
        end
    end
    
    local function serialize_instance(instance)
        local class_name = instance.ClassName
        local ref = get_ref(instance)
        local name = instance.Name or ""
        
        local parts = {}
        table.insert(parts, '<Item class="' .. class_name .. '" referent="' .. ref .. '">')
        table.insert(parts, '<Properties>')
        
        -- Name
        table.insert(parts, '<string name="Name">' .. escape_xml(name) .. '</string>')
        
        -- Visual properties
        local props = get_visual_properties(instance)
        for prop_name, value in pairs(props) do
            local value_str = serialize_value(value)
            if value_str and value_str ~= "null" and value_str ~= "" then
                local tag = get_property_tag(value)
                if tag == "Ref" and type(value) == "Instance" and not should_save_instance(value) then
                    -- Skip references to unsaved instances
                else
                    table.insert(parts, '<' .. tag .. ' name="' .. prop_name .. '">' .. value_str .. '</' .. tag .. '>')
                end
            end
        end
        
        table.insert(parts, '</Properties>')
        
        -- Children (only if they should be saved)
        local children = instance:GetChildren()
        local any_saved = false
        for _, child in ipairs(children) do
            if should_save_instance(child) then
                local child_xml = serialize_instance(child)
                if child_xml then
                    table.insert(parts, child_xml)
                    any_saved = true
                end
            end
        end
        
        table.insert(parts, '</Item>')
        return table.concat(parts)
    end
    
    -- Build the XML
    print("Scanning instances...")
    
    local xml_parts = {}
    table.insert(xml_parts, '<roblox version="4">')
    
    -- Serialize the workspace object
    local success, result = pcall(function()
        return serialize_instance(workspace_obj)
    end)
    
    if success and result then
        table.insert(xml_parts, result)
        print("Serialization successful")
    else
        print("Serialization failed:", result)
        return
    end
    
    table.insert(xml_parts, '</roblox>')
    
    local full_xml = table.concat(xml_parts)
    
    -- Save to file
    local file_path = file_name .. ".rbxmx"
    
    local write_success, write_error = pcall(function()
        if writefile then
            writefile(file_path, full_xml)
        elseif appendfile then
            appendfile(file_path, full_xml)
        else
            -- Try to use console output as fallback
            print("No writefile function available. Outputting to console...")
            print("XML length:", #full_xml)
            return
        end
    end)
    
    if write_success then
        print("File saved successfully:", file_path)
        print("Total referents:", ref_count)
        print("File size:", #full_xml, "bytes")
    else
        print("Failed to save file:", write_error)
    end
end

-- ============================================================
-- AUTO-RUN
-- ============================================================
print("Model & Texture Saver loaded!")
print("")
print("Options:")
print("  - Save: game.Workspace (all models, parts, meshes, textures)")
print("  - Skip: Scripts, LocalScripts, ModuleScripts, UI elements")
print("  - Output: .rbxmx file in executor folder")
print("")

-- Save the workspace
SaveModelAndTextures(game.Workspace, "workspace_models_" .. os.time())

-- Optional: Save additional locations
-- SaveModelAndTextures(game.Lighting, "lighting_models")
-- SaveModelAndTextures(game.ReplicatedStorage, "replicated_models")

print("")
print("=== COMPLETE ===")
