
void Start()
{
    // Register a menu item to open the Bulk Rename window
    Plugin::RegisterMenuItem("Bulk Rename", "Action_BulkRename");
    SubscribeToEvent("Action_BulkRename", "Action_BulkRename");
    
    Plugin::RegisterPropertyPage("NavigationMesh", "void Page_NavButtons(NavigationMesh@)", true);
    Plugin::RegisterPropertyPage("DynamicNavigationMesh", "void Page_NavButtons(NavigationMesh@)", true);
    SubscribeToEvent("ASSET_BROWSER_CONTEXT", "CubeMapContextMenu");
}

void Action_BulkRename(StringHash eventType, VariantMap& eventData)
{
    Editor::ShowToolWindow("Bulk Rename", "void BulkRenameWindow()");
}

String renamingName = "";
void BulkRenameWindow()
{
    if (Editor::GetSelectionCount() > 0)
    {
        ImGui::Text("Rename To:");
        ImGui::InputText("##renaming_field", renamingName);
        ImGui::Separator();
        if (ImGui::Button("Apply Renaming"))
        {
            int selCt = Editor::GetSelectionCount();
            for (int i = 0; i < selCt; ++i)
            {
                Node@ node = cast<Node>(Editor::GetSelected(i));
                if (node != null)
                    node.name = renamingName;
            }
        }        
    }
    else
    {
        ImGui::Text("^1< nothing selected to rename >");
    }
}

void Page_NavButtons(NavigationMesh@ mesh)
{
    ImGui::Separator();
    ImGuiUX::PushLargeBoldFont();
    if (ImGui::Button("Rebuild NavMesh"))
        mesh.Build();
    ImGuiUX::PopFont();
}

void CubeMapContextMenu(StringHash eventType, VariantMap& eventData)
{
    String xmlRoot = eventData["XmlRoot"].GetString();
    if (xmlRoot == "cubemap")
    {
        if (ImGui::MenuItem("CMFT Radiance Filter"))
            FilterCubeMap(eventData["SelectedAssetPath"].GetString());
    }
}

void FilterCubeMap(String xmlPath)
{
    XMLFile@ file = XMLFile();
    if (file.Load(xmlPath))
    {
        String outFile = ReplaceExtension(xmlPath, ""); // for CMFT
        String actualOutFile = outFile + ".dds";
        XMLElement elem = file.root.GetChild("face");
        
        // Don't try to filter a cubemap that has probably already been filtered
        if (file.root.GetChild("image").notNull)
        {
            log.Error("Cubemap " + xmlPath + " has already been filtered");
            return;
        }
        
        String pX = elem.GetAttribute("name");
        elem = elem.GetNext("face");
        String nX = elem.GetAttribute("name");
        elem = elem.GetNext("face");
        
        String pY = elem.GetAttribute("name");
        elem = elem.GetNext("face");
        String nY = elem.GetAttribute("name");
        elem = elem.GetNext("face");
        
        String pZ = elem.GetAttribute("name");
        elem = elem.GetNext("face");
        String nZ = elem.GetAttribute("name");
        
        log.Debug(outFile);
        
        Array<String> args;
        String execPath = "--filter radiance --inputFacePosX " + pX + " --inputFaceNegX " + nX +
            " --inputFacePosY " + pY + " --inputFaceNegY " + nY + " --inputFacePosZ " + pZ + " --inputFaceNegZ " + nZ + " --outputNum 1 --output0params dds,rgba16,cubemap --generateMipChain true --excludeBase true --deviceType cpu --output0 " + outFile;
            
        ui.useSystemClipboard = true;
        ui.clipBoardText = execPath;
        args.Push(execPath);
        log.Debug(execPath);
        
        fileSystem.SystemRun("cmft.exe", args);
        
        {
            XMLFile@ newXML = XMLFile();
            XMLElement root = newXML.CreateRoot("cubemap");
            XMLElement image = root.CreateChild("image");
            image.SetAttribute("name", cache.SanitateResourceName(outFile + ".dds"));
            newXML.Save(File(xmlPath, FILE_WRITE));
            
            fileSystem.Delete(pX);
            fileSystem.Delete(pY);
            fileSystem.Delete(pZ);
            fileSystem.Delete(nX);
            fileSystem.Delete(nY);
            fileSystem.Delete(nZ);
        }
    }
}