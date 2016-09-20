tool
extends ScrollContainer

const SELECTION_TOOL_NONE = 0
const SELECTION_TOOL_VERTEX = 1
const SELECTION_TOOL_EDGES = 2
const SELECTION_TOOL_LOOP = 3
const SELECTION_TOOL_ALL = 4
const SELECTION_TOOL_INVERSE = 5

var wftScript #reference to wireframetool.gd
var buttons = []
var isDockDisabled = false
var isWFTDisabled = true

func _enter_tree():
	get_node("vbox/btnHelp").connect("pressed", wftScript, "showHelp")
	buttons.append(get_node("vbox/hboxSur1/btnTMesh"))
	buttons[0].set_text("Mesh")#this doesn't work in editor
	buttons[0].connect("item_selected", wftScript, "targetMeshSelection")
	buttons.append(get_node("vbox/hboxSur1/btnTSur"))
	buttons[1].set_text("Surface")
	buttons[1].connect("item_selected", wftScript, "targetSurfaceSelection")
	
	buttons.append(get_node("vbox/hboxSur2/btnRenameS"))
	buttons[2].connect("pressed", wftScript, "renameSurface")
	#buttons.append(get_node("vbox/hboxSur2/txtedSurName"))
	buttons.append(get_node("vbox/hboxSur2/btnRenameOk"))
	buttons[3].connect("pressed", wftScript, "renameSurfaceOK")
	buttons.append(get_node("vbox/hboxSur2/btnDeleteS"))
	buttons[4].connect("pressed", wftScript, "deleteSurface")
	
	buttons.append(get_node("vbox/hboxSur3/btnSMesh"))
	buttons[5].set_text("Mesh")
	buttons[5].connect("item_selected", wftScript, "sourceMeshSelection")
	buttons.append(get_node("vbox/hboxSur3/btnSSur"))
	buttons[6].set_text("Surface")
	buttons.append(get_node("vbox/hboxSur3/btnCopyS"))
	buttons[7].connect("pressed", wftScript, "copySurface")
	
	buttons.append(get_node("vbox/hboxWFT/btnGenerate"))
	buttons[8].connect("pressed", wftScript, "generateWirefame")
	buttons.append(get_node("vbox/hboxWFT/btnCommit"))
	buttons[9].connect("pressed", wftScript, "commitWireframe")
	buttons.append(get_node("vbox/hboxWFT/btnCancel"))
	buttons[10].connect("pressed", wftScript, "cancelWireframe")
	
	buttons.append(get_node("vbox/group/GridContainer/btnNone"))
	buttons[11].connect("pressed", self, "setToolNone")
	buttons.append(get_node("vbox/group/GridContainer/btnVertex"))
	buttons[12].connect("pressed", self, "setToolVertex")
	buttons.append(get_node("vbox/group/GridContainer/btnEdge"))
	buttons[13].connect("pressed", self, "setToolEdge")
	buttons.append(get_node("vbox/group/GridContainer/btnLoop"))
	buttons[14].connect("pressed", self, "setToolLoop")
	buttons.append(get_node("vbox/group/GridContainer/btnAll"))
	buttons[15].connect("pressed", self, "setToolALL")
	buttons.append(get_node("vbox/group/GridContainer/btnInverse"))
	buttons[16].connect("pressed", self, "setToolInverse")
	
	buttons.append(get_node("vbox/gridActions/btnDelete"))
	buttons[17].connect("pressed", wftScript, "deleteSelection")
	buttons.append(get_node("vbox/gridActions/btnColor"))
	buttons[18].connect("pressed", wftScript, "colorSelection")
	buttons.append(get_node("vbox/gridActions/ColorPickerButton"))

	buttons.append(get_node("vbox/hboxMaterials/btnUnlit"))
	buttons[20].connect("pressed", wftScript, "setUnlitShader")
	buttons.append(get_node("vbox/hboxMaterials/btnLit"))
	buttons[21].connect("pressed", wftScript, "setLitShader")
	buttons.append(get_node("vbox/hboxMaterials/btnOutline"))
	buttons[22].connect("pressed", wftScript, "setOutlineShader")
	get_node("vbox/hboxMaterials/btnOccluder").connect("pressed", wftScript, "setOccluderShader")
	disableAll(true)

func _exit_tree():
	get_node("vbox/btnHelp").disconnect("pressed", wftScript, "showHelp")
	buttons[0].disconnect("item_selected", wftScript, "targetMeshSelection")
	buttons[1].disconnect("item_selected", wftScript, "targetSurfaceSelection")
	buttons[2].disconnect("pressed", wftScript, "renameSurface")
	buttons[3].disconnect("pressed", wftScript, "renameSurfaceOK")
	buttons[4].disconnect("pressed", wftScript, "deleteSurface")
	buttons[5].disconnect("item_selected", wftScript, "sourceMeshSelection")
	buttons[7].disconnect("pressed", wftScript, "copySurface")
	buttons[8].disconnect("pressed", wftScript, "generateWirefame")
	buttons[9].disconnect("pressed", wftScript, "commitWireframe")
	buttons[10].disconnect("pressed", wftScript, "cancelWireframe")
	buttons[11].disconnect("pressed", self, "setToolNone")
	buttons[12].disconnect("pressed", self, "setToolVertex")
	buttons[13].disconnect("pressed", self, "setToolEdge")
	buttons[14].disconnect("pressed", self, "setToolLoop")
	buttons[15].disconnect("pressed", self, "setToolALL")
	buttons[16].disconnect("pressed", self, "setToolInverse")
	buttons[17].disconnect("pressed", wftScript, "deleteSelection")
	buttons[18].disconnect("pressed", wftScript, "colorSelection")
	buttons[20].disconnect("pressed", wftScript, "setUnlitShader")
	buttons[21].disconnect("pressed", wftScript, "setLitShader")
	buttons[22].disconnect("pressed", wftScript, "setOutlineShader")
	get_node("vbox/hboxMaterials/btnOccluder").disconnect("pressed", wftScript, "setOccluderShader")

func setToolNone():
	wftScript.activeTool = SELECTION_TOOL_NONE
func setToolVertex():
	wftScript.activeTool = SELECTION_TOOL_VERTEX
func setToolEdge():
	wftScript.activeTool = SELECTION_TOOL_EDGES
func setToolLoop():
	wftScript.activeTool = SELECTION_TOOL_LOOP
func setToolALL():
	wftScript.activeTool = SELECTION_TOOL_ALL
func setToolInverse():
	wftScript.activeTool = SELECTION_TOOL_INVERSE

func setTargetMeshName(name, uid):
	buttons[0].add_item(name, uid)

func setTargetSurfaceName(name):
	buttons[1].add_item(name)

func setSourceMeshName(name, uid):
	buttons[5].add_item(name, uid)

func setSourceSurfaceName(name):
	buttons[6].add_item(name)

#########################################################################

func getSelTargetMeshId():
	return buttons[0].get_selected_ID()

func getSelTargetSurfaceName():
	return buttons[1].get_item_text(buttons[1].get_selected())

func getSelSourceMeshId():
	return buttons[5].get_selected_ID()

func getSelSourceSurfaceName():
	return buttons[6].get_item_text(buttons[6].get_selected())

#########################################################################

func clearSelTargetMesh():
	buttons[0].clear()

func clearSelTargetSurface():
	buttons[1].clear()

func clearSelSourceMesh():
	buttons[5].clear()

func clearSelSourceSurface():
	buttons[6].clear()

###########################################
func getColor():
	return get_node("vbox/gridActions/ColorPickerButton").get_color()

func setColor(color):
	get_node("vbox/gridActions/ColorPickerButton").set_color(color)

func setWarning(text):
	get_node("vbox/lblWarning").set_text(text)

func getWarning():
	return get_node("vbox/lblWarning").get_text()

func getRenameSurfaceText():
	return get_node("vbox/hboxSur2/txtedSurName").get_text()

func showRenameSurface(show):
		buttons[2].set_hidden(show)
		get_node("vbox/hboxSur2/txtedSurName").set_hidden(!show)
		buttons[3].set_hidden(!show)
		if (show):
			get_node("vbox/hboxSur2/txtedSurName").set_text(getSelTargetSurfaceName())

func disableTarget(disable):
	buttons[0].set_disabled(disable)
	buttons[1].set_disabled(disable)
	buttons[2].set_disabled(disable)
	buttons[3].set_disabled(disable)
	buttons[4].set_disabled(disable)

func disableSurfaceCopy(disable):
	buttons[5].set_disabled(disable)
	buttons[6].set_disabled(disable)
	buttons[7].set_disabled(disable)

func disableWFT(disable):
	isWFTDisabled = disable
	buttons[8].set_disabled(!disable)
	buttons[9].set_disabled(disable)
	buttons[10].set_disabled(disable)
	buttons[11].set_disabled(disable)
	buttons[12].set_disabled(disable)
	buttons[13].set_disabled(disable)
	buttons[14].set_disabled(disable)
	buttons[15].set_disabled(disable)
	buttons[16].set_disabled(disable)
	buttons[17].set_disabled(disable)
	buttons[18].set_disabled(disable)
	buttons[19].set_disabled(disable)
	buttons[20].set_disabled(disable)
	buttons[21].set_disabled(disable)
	buttons[22].set_disabled(disable)
	buttons[22].set_disabled(disable)

func disableAll(disable):
		for button in buttons:
			if (!button.is_disabled()):
				button.set_disabled(disable)

func cleanAndLock():
	buttons[0].clear()
	buttons[1].clear()
	buttons[5].clear()
	buttons[6].clear()
	disableAll(true)