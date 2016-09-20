tool
extends EditorPlugin

var canEdit = false
var selectedNodes
var dock = preload("res://addons/Wireframe Tool/dock.tscn").instance()
var activeTool = dock.SELECTION_TOOL_EDGES
var editedMaterial = preload("res://addons/Wireframe Tool/materials/editMat.tres") #material for vertex color preview (unshaded)
var helpDialog = preload("res://addons/Wireframe Tool/helpDialog.tscn").instance()
var nameCounter = 0
var edgeSelector = []
var vertexSelector = -1

##################### ENGINE CALLBACKS #############################################

func _enter_tree():
	get_selection().connect("selection_changed", self, "selectionChanged")
	get_base_control().add_child(helpDialog)
	dock.wftScript = self
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, dock)

func _exit_tree():
	get_selection().disconnect("selection_changed", self, "selectionChanged")
	get_base_control().remove_child(helpDialog)
	helpDialog.free()
	remove_control_from_docks(dock)
	dock.free()

func forward_spatial_input_event(camera, event):
	if (!canEdit):
		return
	if (event.type == InputEvent.MOUSE_BUTTON):
		if (event.button_index == BUTTON_LEFT and event.pressed):
			var targetMesh = selectedNodes[dock.getSelTargetMeshId()].get_mesh()
			var surfaceName = dock.getSelTargetSurfaceName()
			
			if (activeTool == dock.SELECTION_TOOL_NONE):
				return
			elif (event.alt or activeTool == dock.SELECTION_TOOL_VERTEX): 
				#vertex selector
				var ids = surfaceNameToId(targetMesh, surfaceName)
				var meshTool = MeshDataTool.new()
				meshTool.create_from_surface(targetMesh.get_meta("orgMesh"), int(ids.y))
				edgeSelector.clear()
				var index
				var oldDistance = 1000000
				
				for i in range(meshTool.get_vertex_count()):
					if (testEdges(meshTool, i, targetMesh.get_meta("VEL")[surfaceName])):
						var vertex = meshTool.get_vertex(i)
						vertex = camera.unproject_position(selectedNodes[dock.getSelTargetMeshId()].get_transform().basis * vertex + selectedNodes[dock.getSelTargetMeshId()].get_transform().origin)
						var distance = vertex.distance_to(event.pos)
						if (distance < oldDistance):
							oldDistance = distance
							index = i
				
				if (vertexSelector == index):
					vertexSelector = -1
				else:
					vertexSelector = index
					#color picker
					if (event.control):
						if (meshTool.get_edge_vertex(meshTool.get_vertex_edges(vertexSelector)[0], 0) == vertexSelector):
							dock.setColor(targetMesh.get_meta("COL")[surfaceName][meshTool.get_vertex_edges(vertexSelector)[0]*2])
						else:
							dock.setColor(targetMesh.get_meta("COL")[surfaceName][meshTool.get_vertex_edges(vertexSelector)[0]*2+1])
				generateWireframeMesh(meshTool, targetMesh, int(ids.x), surfaceName)
				return true
			elif (activeTool == dock.SELECTION_TOOL_EDGES):
				 #edge selector
				var ids = surfaceNameToId(targetMesh, surfaceName)
				var meshTool = MeshDataTool.new()
				meshTool.create_from_surface(targetMesh.get_meta("orgMesh"), int(ids.y))
				vertexSelector = -1
				var edgeIndex = -1
				var oldDistance = 1000000
				
				for visEdge in targetMesh.get_meta("VEL")[surfaceName]:
					var edgePoint1 = meshTool.get_vertex(meshTool.get_edge_vertex(visEdge, 0))
					var edgePoint2 = meshTool.get_vertex(meshTool.get_edge_vertex(visEdge, 1))
					var vertex = edgePoint1.linear_interpolate(edgePoint2, 0.5)
					#transform and unproject the points
					edgePoint1 = camera.unproject_position(selectedNodes[dock.getSelTargetMeshId()].get_transform().basis * edgePoint1 + selectedNodes[dock.getSelTargetMeshId()].get_transform().origin)
					edgePoint2 = camera.unproject_position(selectedNodes[dock.getSelTargetMeshId()].get_transform().basis * edgePoint2 + selectedNodes[dock.getSelTargetMeshId()].get_transform().origin)
					var distance = distanceToEdge(edgePoint1, edgePoint2, event.pos) #transform them!!
					#TODO
					if (distance < oldDistance):
						oldDistance = distance
						edgeIndex = visEdge
				
				if (edgeIndex != -1):
					if (edgeIndex in edgeSelector):
						edgeSelector.erase(edgeIndex)
					else:
						edgeSelector.append(edgeIndex)
				generateWireframeMesh(meshTool, targetMesh, int(ids.x), surfaceName)
				return true
			elif (activeTool == dock.SELECTION_TOOL_ALL):
				selectAll(targetMesh, surfaceName)
				return true
			elif (activeTool == dock.SELECTION_TOOL_INVERSE):
				selectInverse(targetMesh, surfaceName)
				return true
	elif (event.type == InputEvent.KEY):
		if (event.scancode == KEY_D and event.pressed):
			deleteSelection()
		elif (event.scancode == KEY_C and event.pressed):
			colorSelection()
		elif (event.scancode == KEY_A and event.pressed):
			selectAll(selectedNodes[dock.getSelTargetMeshId()].get_mesh(), dock.getSelTargetSurfaceName())
		elif (event.scancode == KEY_I and event.pressed):
			selectInverse(selectedNodes[dock.getSelTargetMeshId()].get_mesh(), dock.getSelTargetSurfaceName())
		return false

func clear():
	if (selectedNodes != null):
		selectedNodes.clear()

func handles(object):
	#this throws a shit ton of errors in console
	#and it can't handle multiple selected nodes so far
#	yield(get_selection(), "selection_changed")
	return object extends MeshInstance 

########################## SIGNALS ################################

func targetMeshSelection(id):
	dock.clearSelTargetSurface()
	surfaceGUIFill(selectedNodes[id].get_mesh(), true)
	surfaceGUITest(selectedNodes[id].get_mesh(), dock.getSelTargetSurfaceName())
	dock.showRenameSurface(false)

func targetSurfaceSelection(id):
	surfaceGUITest(selectedNodes[dock.getSelTargetMeshId()].get_mesh(), dock.getSelTargetSurfaceName())
	dock.showRenameSurface(false)

func sourceMeshSelection(id):
	dock.clearSelSourceSurface()
	surfaceGUIFill(selectedNodes[id].get_mesh(), false)

func renameSurface():
	dock.showRenameSurface(true)

func renameSurfaceOK():
	if (dock.getRenameSurfaceText() == dock.getSelTargetSurfaceName() or dock.getRenameSurfaceText() == ""):
		dock.setWarning("Surface wasn't renamed.")
		dock.showRenameSurface(false)
		return
	var targetMesh = selectedNodes[dock.getSelTargetMeshId()].get_mesh()
	var sId = -1
	var sIdOrgMesh = -1
	var oldName = dock.getSelTargetSurfaceName()
	var newName = dock.getRenameSurfaceText()
	#find old surfaces in mesh and metadata, also test against collisions
	for i in range(targetMesh.get_surface_count()):
		if (newName == targetMesh.surface_get_name(i)):
			dock.setWarning("Some surface in target has same name. Please choose an unique name.")
			return
		if (oldName == targetMesh.surface_get_name(i)):
			sId = i
		if (targetMesh.has_meta("orgMesh")):
			if (i < targetMesh.get_meta("orgMesh").get_surface_count()):
				if (oldName == targetMesh.get_meta("orgMesh").surface_get_name(i)):
					sIdOrgMesh = i
	if (sId != -1):
		targetMesh.surface_set_name(sId, newName)
	if (sIdOrgMesh != -1):
		targetMesh.get_meta("orgMesh").surface_set_name(sIdOrgMesh, newName)
		targetMesh.get_meta("VEL")[newName] = targetMesh.get_meta("VEL")[oldName]
		targetMesh.get_meta("VEL").erase(oldName)
		targetMesh.get_meta("COL")[newName] = targetMesh.get_meta("COL")[oldName]
		targetMesh.get_meta("COL").erase(oldName)
	dock.showRenameSurface(false)
	dock.clearSelTargetSurface()
	dock.clearSelSourceSurface()
	surfaceGUIFill(targetMesh, true)
	if (selectedNodes.size() > 1):
		surfaceGUIFill(selectedNodes[dock.getSelSourceMeshId()].get_mesh(), false)
	surfaceGUITest(targetMesh, dock.getSelTargetSurfaceName())

#TODO this throws errors but works so don't touch
func deleteSurface():
	dock.showRenameSurface(false)
	var targetMesh = selectedNodes[dock.getSelTargetMeshId()].get_mesh()
	var ids = surfaceNameToId(targetMesh, dock.getSelTargetSurfaceName())
	targetMesh.surface_remove(int(ids.x))
	#delete meta
	if (targetMesh.has_meta("orgMesh")):
		targetMesh.get_meta("orgMesh").surface_remove(int(ids.y))
		targetMesh.get_meta("VEL").erase(dock.getSelTargetSurfaceName())
		targetMesh.get_meta("COL").erase(dock.getSelTargetSurfaceName())
		if (targetMesh.get_meta("orgMesh").get_surface_count() == 0):
			targetMesh.set_meta("orgMesh", null)
			targetMesh.set_meta("VEL", null)
			targetMesh.set_meta("COL", null)
	
	dock.clearSelTargetSurface()
	surfaceGUIFill(targetMesh, true)
	surfaceGUITest(targetMesh, dock.getSelTargetSurfaceName())

func copySurface():
	dock.showRenameSurface(false)
	var sourceMesh = selectedNodes[dock.getSelSourceMeshId()].get_mesh()
	var targetMesh = selectedNodes[dock.getSelTargetMeshId()].get_mesh()
	if (sourceMesh == targetMesh):
		dock.setWarning("Target and source meshes are same. Can't copy!")
		return
	#find surface in source
	var surfaceName = dock.getSelSourceSurfaceName()
	var ids = surfaceNameToId(sourceMesh, surfaceName)
	#the name can't collide in target
	for i in range(targetMesh.get_surface_count()):
		if (surfaceName == targetMesh.surface_get_name(i)):
			dock.setWarning("Some surface in target has same name as selected source surface. Can't copy!")
			return
	#no collision
	if (sourceMesh.has_meta("orgMesh")):
		if (int(ids.y) != -1):
			dock.setWarning("Source surface can't be wireframe (not my fault). Can't copy!")
			return
	var meshTool = MeshDataTool.new()
	meshTool.create_from_surface(sourceMesh, int(ids.x))
	meshTool.commit_to_surface(targetMesh)
	#find the new surface and rename him
	targetMesh.surface_set_name(targetMesh.get_surface_count() - 1, surfaceName)
	targetMesh.surface_set_material(targetMesh.get_surface_count() - 1, sourceMesh.surface_get_material(int(ids.x)))
	dock.setWarning("Copied.")
	#MeshDataTool can't use PRIMITIVE_LINES
#	#copy metadata
#	if (sourceMesh.has_meta("orgMesh")):
#		var mt = MeshDataTool.new()
#		mt.create_from_surface(sourceMesh.get_meta("orgMesh"), int(ids.y))
#		if (targetMesh.has_meta("orgMesh")):
#			mt.commit_to_surface(targetMesh.get_meta("orgMesh"))
#			targetMesh.get_meta("orgMesh").surface_set_name(targetMesh.get_meta("orgMesh").get_surface_count() - 1, surfaceName)
#			targetMesh.get_meta("VEL")[surfaceName] = [] + sourceMesh.get_meta("VEL")[surfaceName]
#			targetMesh.get_meta("COL")[surfaceName] = [] + sourceMesh.get_meta("COL")[surfaceName]
#		else:
#			var newMesh = Mesh.new()
#			mt.commit_to_surface(newMesh)
#			newMesh.surface_set_name(0, surfaceName)
#			targetMesh.set_meta("orgMesh", newMesh)
#			targetMesh.set_meta("VEL", [] + sourceMesh.get_meta("VEL")[surfaceName])
#			targetMesh.set_meta("COL", [] + sourceMesh.get_meta("COL")[surfaceName])
	#refresh target surface selection
	dock.clearSelTargetSurface()
	surfaceGUIFill(targetMesh, true)
	surfaceGUITest(targetMesh, dock.getSelTargetSurfaceName())

func generateWirefame():
	if (isMeshInvalid(selectedNodes[dock.getSelTargetMeshId()])):
		return
	var targetMesh = selectedNodes[dock.getSelTargetMeshId()].get_mesh()
	var surfaceName = dock.getSelTargetSurfaceName()
	
	var undoRedo = get_undo_redo()
	undoRedo.create_action("WFT Generate")
	undoRedo.add_do_method(self, "doGenerateWireframe", targetMesh, surfaceName)
	#doCancel is same as undoGenerate
	undoRedo.add_undo_method(self, "doCancelWireframe", selectedNodes[dock.getSelTargetMeshId()], targetMesh, surfaceName)
	undoRedo.commit_action()

func commitWireframe():
	var surfaceName = dock.getSelTargetSurfaceName()
	var mesh = selectedNodes[dock.getSelTargetMeshId()].get_mesh()
	var delArray = [] + mesh.get_meta("VEL")[surfaceName]
	var colArray = [] + mesh.get_meta("COL")[surfaceName]
	var meshTool = MeshDataTool.new()
	meshTool.create_from_surface(mesh.get_meta("orgMesh"), int(surfaceNameToId(mesh, surfaceName).y))
	
	var undoRedo = get_undo_redo()
	undoRedo.create_action("WFT Commit")
	undoRedo.add_do_method(self, "doCommitWireframe", selectedNodes[dock.getSelTargetMeshId()], mesh, surfaceName)
	undoRedo.add_undo_method(self, "undoCommitWireframe", mesh, surfaceName, delArray, meshTool, colArray)
	undoRedo.commit_action()

func cancelWireframe():
	if (isMeshInvalid(selectedNodes[dock.getSelTargetMeshId()])):
		return
	var surfaceName = dock.getSelTargetSurfaceName()
	var mesh = selectedNodes[dock.getSelTargetMeshId()].get_mesh()
	var delArray = [] + mesh.get_meta("VEL")[surfaceName]
	var colArray = [] + mesh.get_meta("COL")[surfaceName]
	var meshTool = MeshDataTool.new()
	meshTool.create_from_surface(mesh.get_meta("orgMesh"), int(surfaceNameToId(mesh, surfaceName).y))
	
	var undoRedo = get_undo_redo()
	undoRedo.create_action("WFT Cancel")
	undoRedo.add_do_method(self, "doCancelWireframe", selectedNodes[dock.getSelTargetMeshId()], mesh, surfaceName)
	undoRedo.add_undo_method(self, "undoCancelWireframe", mesh, surfaceName, delArray, meshTool, colArray)
	undoRedo.commit_action()

func selectionChanged():
	dock.showRenameSurface(false)
	dock.setWarning("")
	selectedNodes = get_selection().get_selected_nodes()
	edgeSelector.clear()
	vertexSelector = -1
	dock.clearSelTargetMesh()
	dock.clearSelSourceMesh()
	dock.clearSelTargetSurface()
	dock.clearSelSourceSurface()
	var i = -1
	var validNodes = 0
	for node in selectedNodes:
		i += 1 
		if (node extends MeshInstance):
			if (!isMeshInvalid(node)): #mesh is valid, add it to target and source
				dock.setTargetMeshName(node.get_name(), i)
				dock.setSourceMeshName(node.get_name(), i)
				validNodes += 1 
	#we filled target and source with valid MI nodes
	if (validNodes == 0): #no valid node, disable all and return
		dock.setWarning("%s No valid node selected." % dock.getWarning())
		dock.cleanAndLock()
		canEdit = false
		return
	elif (validNodes == 1): #one node - disable copy, enable target
		dock.setWarning("One valid node selected.")
		dock.clearSelSourceMesh()
		dock.disableSurfaceCopy(true)
		dock.disableTarget(false)
	elif (validNodes > 1): #more than one node, enable copy and target, remove sel. target mesh from source mesh list
		dock.setWarning("%d valid nodes selected." % validNodes)
		dock.disableSurfaceCopy(false)
		dock.disableTarget(false)
		surfaceGUIFill(selectedNodes[dock.getSelSourceMeshId()].get_mesh(), false) #fill source surface list
	surfaceGUIFill(selectedNodes[dock.getSelTargetMeshId()].get_mesh(), true)
	#surfaces are filled, test the selected one
	return surfaceGUITest(selectedNodes[dock.getSelTargetMeshId()].get_mesh(), dock.getSelTargetSurfaceName())

func deleteSelection():
	#delete vertex - just put edges to edgeSelector
	if (vertexSelector != -1):
		var targetMesh = selectedNodes[dock.getSelTargetMeshId()].get_mesh()
		var meshTool = MeshDataTool.new()
		var ids = surfaceNameToId(targetMesh, dock.getSelTargetSurfaceName())
		var meshTool = MeshDataTool.new()
		meshTool.create_from_surface(targetMesh.get_meta("orgMesh"), int(ids.y))
		
		for edgeIndex in meshTool.get_vertex_edges(vertexSelector):
			edgeSelector.append(edgeIndex)
		
		vertexSelector = -1
	
	if (edgeSelector.size() > 0):
		var targetMesh = selectedNodes[dock.getSelTargetMeshId()].get_mesh()
		var undoRedo = get_undo_redo()
		undoRedo.create_action("WFT Delete Edges")
		undoRedo.add_do_method(self, "doDeleteEdges", [] + edgeSelector, targetMesh, dock.getSelTargetSurfaceName())
		undoRedo.add_undo_method(self, "undoDeleteEdges", [] + edgeSelector, targetMesh, dock.getSelTargetSurfaceName())
		undoRedo.commit_action()
		edgeSelector.clear()

#TODO undo/redo
func colorSelection():
	if (edgeSelector.size() > 0):
		var mesh = selectedNodes[dock.getSelTargetMeshId()].get_mesh()
		var surfaceName = dock.getSelTargetSurfaceName()
		var ids = surfaceNameToId(mesh, surfaceName)
		var meshTool = MeshDataTool.new()
		meshTool.create_from_surface(mesh.get_meta("orgMesh"), int(ids.y))
		
		for edge in edgeSelector:
			mesh.get_meta("COL")[surfaceName][edge*2] = dock.getColor()
			mesh.get_meta("COL")[surfaceName][edge*2+1] = dock.getColor()
		
		generateWireframeMesh(meshTool, mesh, int(ids.x), surfaceName)
		
	elif (vertexSelector != -1):
		var mesh = selectedNodes[dock.getSelTargetMeshId()].get_mesh()
		var surfaceName = dock.getSelTargetSurfaceName()
		var ids = surfaceNameToId(mesh, surfaceName)
		var meshTool = MeshDataTool.new()
		meshTool.create_from_surface(mesh.get_meta("orgMesh"), int(ids.y))
		
		for edge in meshTool.get_vertex_edges(vertexSelector):
			if (meshTool.get_edge_vertex(edge, 0) == vertexSelector):
				mesh.get_meta("COL")[surfaceName][edge*2] = dock.getColor()
			else:
				mesh.get_meta("COL")[surfaceName][edge*2+1] = dock.getColor()
		
		generateWireframeMesh(meshTool, mesh, int(ids.x), surfaceName)

func setUnlitShader():
	if (isMeshInvalid(selectedNodes[dock.getSelTargetMeshId()])):
		return
	var ids = surfaceNameToId(selectedNodes[dock.getSelTargetMeshId()].get_mesh(), dock.getSelTargetSurfaceName())
	selectedNodes[dock.getSelTargetMeshId()].get_mesh().surface_set_material(int(ids.x), editedMaterial)

func setLitShader():
	if (isMeshInvalid(selectedNodes[dock.getSelTargetMeshId()])):
		return
	var ids = surfaceNameToId(selectedNodes[dock.getSelTargetMeshId()].get_mesh(), dock.getSelTargetSurfaceName())
	selectedNodes[dock.getSelTargetMeshId()].get_mesh().surface_set_material(int(ids.x), load("res://addons/Wireframe Tool/materials/litMat.tres"))

func setOutlineShader():
	if (isMeshInvalid(selectedNodes[dock.getSelTargetMeshId()])):
		return
	var ids = surfaceNameToId(selectedNodes[dock.getSelTargetMeshId()].get_mesh(), dock.getSelTargetSurfaceName())
	selectedNodes[dock.getSelTargetMeshId()].get_mesh().surface_set_material(int(ids.x), load("res://addons/Wireframe Tool/materials/outlineMat.tres"))

func setOccluderShader():
	if (isMeshInvalid(selectedNodes[dock.getSelTargetMeshId()])):
		return
	var ids = surfaceNameToId(selectedNodes[dock.getSelTargetMeshId()].get_mesh(), dock.getSelTargetSurfaceName())
	selectedNodes[dock.getSelTargetMeshId()].get_mesh().surface_set_material(int(ids.x), load("res://addons/Wireframe Tool/materials/occluderMat.tres"))

func showHelp():
	helpDialog.popup_centered()

###################### HELPER FUNCTIONS #####################################

func generateWireframeMesh(meshTool, mesh, surfaceId, surfaceName):
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_LINES)
	
	for visEdge in mesh.get_meta("VEL")[surfaceName]:
		if (visEdge in edgeSelector or vertexSelector == meshTool.get_edge_vertex(visEdge, 0)):
			surfaceTool.add_color(mesh.get_meta("COL")[surfaceName][visEdge*2].inverted())
		else:
			surfaceTool.add_color(mesh.get_meta("COL")[surfaceName][visEdge*2])
		
		surfaceTool.add_normal(meshTool.get_vertex_normal(meshTool.get_edge_vertex(visEdge, 0)))
		#FIXME - not sure if those two are connected but I'm too lazy to test it
		if (meshTool.get_vertex_bones(meshTool.get_edge_vertex(visEdge, 0)).size() != 0):
			surfaceTool.add_weights(meshTool.get_vertex_weights(meshTool.get_edge_vertex(visEdge, 0)))
			surfaceTool.add_bones(meshTool.get_vertex_bones(meshTool.get_edge_vertex(visEdge, 0)))
		surfaceTool.add_uv(meshTool.get_vertex_uv(meshTool.get_edge_vertex(visEdge, 0)))
		surfaceTool.add_vertex(meshTool.get_vertex(meshTool.get_edge_vertex(visEdge, 0)))
		
		if (visEdge in edgeSelector or vertexSelector == meshTool.get_edge_vertex(visEdge, 1)):
			surfaceTool.add_color(mesh.get_meta("COL")[surfaceName][visEdge*2+1].inverted())
		else:
			surfaceTool.add_color(mesh.get_meta("COL")[surfaceName][visEdge*2+1])
		
		surfaceTool.add_normal(meshTool.get_vertex_normal(meshTool.get_edge_vertex(visEdge, 1)))
		if (meshTool.get_vertex_bones(meshTool.get_edge_vertex(visEdge, 1)).size() != 0):
			surfaceTool.add_weights(meshTool.get_vertex_weights(meshTool.get_edge_vertex(visEdge, 1)))
			surfaceTool.add_bones(meshTool.get_vertex_bones(meshTool.get_edge_vertex(visEdge, 1)))
		surfaceTool.add_uv(meshTool.get_vertex_uv(meshTool.get_edge_vertex(visEdge, 1)))
		surfaceTool.add_vertex(meshTool.get_vertex(meshTool.get_edge_vertex(visEdge, 1)))
	
	var oldMat = mesh.surface_get_material(surfaceId)
	mesh.surface_set_material(surfaceId, null)	
	mesh.surface_remove(surfaceId)
	surfaceTool.commit(mesh)
	mesh.surface_set_name(mesh.get_surface_count() - 1, surfaceName)
	mesh.surface_set_material(mesh.get_surface_count() - 1, oldMat)

#fill surface list from mesh - if isTarget = false -> it's source, do name check
func surfaceGUIFill(mesh, isTarget):
	var renSurCount = 0
	for i in range(mesh.get_surface_count()):
		if (mesh.surface_get_name(i) == ""):
			renSurCount += 1
			dock.setWarning("Found %d surface(s) without name! Every surface needs to have an unique name. I named them for you." % renSurCount)
			mesh.surface_set_name(i, "sur_%d" % nameCounter)
			nameCounter += 1
		if (isTarget):
			dock.setTargetSurfaceName(mesh.surface_get_name(i))
		else:
			dock.setSourceSurfaceName(mesh.surface_get_name(i))

#test if surface is in metadata - to set the GUI
func surfaceGUITest(mesh, surfaceName):
	if (mesh.has_meta("orgMesh")): #we can't assume the mesh was edited by this tool before
		for i in range(mesh.get_meta("orgMesh").get_surface_count()):
			if (mesh.get_meta("orgMesh").surface_get_name(i) == surfaceName): #we find selected surface in metadata
				dock.disableWFT(false) #turn on tools
				canEdit = true
				return
		dock.disableWFT(true)
		canEdit = false
		return
	else: #no meta find, there's no surface to look for
		dock.disableWFT(true)
		canEdit = false
		return

#find surface id in mesh and metadata orgMest TODO add this where needed
func surfaceNameToId(mesh, name):
	var ids = Vector2(-1, -1)
	for i in range(mesh.get_surface_count()):
		if (mesh.surface_get_name(i) == name):
			ids.x = float(i)
		if (mesh.has_meta("orgMesh")):
			if (i < mesh.get_meta("orgMesh").get_surface_count()):
				if (name == mesh.get_meta("orgMesh").surface_get_name(i)):
					ids.y = float(i)
	return ids

#tests if the vertex edges are on the list of deleted edges
func testEdges(meshTool, vertexIndex, arrayVEL):
	var edges = meshTool.get_vertex_edges(vertexIndex)
	for edgeIndex in edges:
		if (edgeIndex in arrayVEL):
			return true
	return false

#find closest line segment
func distanceToEdge(edgePoint1, edgePoint2, point):
	var l2 = edgePoint1.distance_squared_to(edgePoint2)
	var pe1 = point - edgePoint1
	var t = max(0.0, min(1.0, pe1.dot(edgePoint2 - edgePoint1) / l2))
	var projection = edgePoint1 + t * (edgePoint2 - edgePoint1)
	return point.distance_to(projection)

func isMeshInvalid(meshInstance):
	if (meshInstance.get_mesh() == null):
		dock.setWarning("Selected MeshInstance doesn't have Mesh property!")
		return true
	elif (meshInstance.get_mesh().get_surface_count() == 0):
		dock.setWarning("Mesh doesn't have any surface!")
		return true
	else:
		return false

func selectAll(targetMesh, surfaceName):
	var ids = surfaceNameToId(targetMesh, surfaceName)
	var meshTool = MeshDataTool.new()
	meshTool.create_from_surface(targetMesh.get_meta("orgMesh"), int(ids.y))
	vertexSelector = -1
	
	if (edgeSelector.size() == targetMesh.get_meta("VEL")[surfaceName].size()):
		edgeSelector.clear()
		generateWireframeMesh(meshTool, targetMesh, int(ids.x), surfaceName)
		return
	for visEdge in targetMesh.get_meta("VEL")[surfaceName]:
		if (! visEdge in edgeSelector):
			edgeSelector.append(visEdge)
	generateWireframeMesh(meshTool, targetMesh, int(ids.x), surfaceName)

func selectInverse(targetMesh, surfaceName):
	var ids = surfaceNameToId(targetMesh, surfaceName)
	var meshTool = MeshDataTool.new()
	meshTool.create_from_surface(targetMesh.get_meta("orgMesh"), int(ids.y))
	vertexSelector = -1
	
	for visEdge in targetMesh.get_meta("VEL")[surfaceName]:
		if (visEdge in edgeSelector):
			edgeSelector.erase(visEdge)
		else:
			edgeSelector.append(visEdge)
	generateWireframeMesh(meshTool, targetMesh, int(ids.x), surfaceName)

############################ UNDO/REDO ########################################

func doDeleteEdges(arrayEdges, mesh, surfaceName):
	for edge in arrayEdges:
		mesh.get_meta("VEL")[surfaceName].erase(edge)
	
	var ids = surfaceNameToId(mesh, surfaceName)
	var meshTool = MeshDataTool.new()
	meshTool.create_from_surface(mesh.get_meta("orgMesh"), int(ids.y))
	generateWireframeMesh(meshTool, mesh, int(ids.x), surfaceName)

func undoDeleteEdges(arrayEdges, mesh, surfaceName):
	for edge in arrayEdges:
		mesh.get_meta("VEL")[surfaceName].append(edge)
	
	var ids = surfaceNameToId(mesh, surfaceName)
	var meshTool = MeshDataTool.new()
	meshTool.create_from_surface(mesh.get_meta("orgMesh"), int(ids.y))
	generateWireframeMesh(meshTool, mesh, int(ids.x), surfaceName)

func doCommitWireframe(meshInstance, targetMesh, surfaceName):
	if (isMeshInvalid(meshInstance)):
		return
	var ids = surfaceNameToId(targetMesh, surfaceName)
	var meshTool = MeshDataTool.new()
	meshTool.create_from_surface(targetMesh.get_meta("orgMesh"), int(ids.y))
	vertexSelector = -1
	edgeSelector.clear()
	generateWireframeMesh(meshTool, targetMesh, int(ids.x), surfaceName)
	
	targetMesh.get_meta("orgMesh").surface_remove(int(ids.y))
	targetMesh.get_meta("VEL").erase(surfaceName)
	targetMesh.get_meta("COL").erase(surfaceName)
	targetMesh.surface_set_material(int(ids.x), null)
	
	if (targetMesh.get_meta("orgMesh").get_surface_count() == 0):
		targetMesh.set_meta("orgMesh", null)
		targetMesh.set_meta("VEL", null)
		targetMesh.set_meta("COL", null)
	
	surfaceGUITest(targetMesh, surfaceName)

func undoCommitWireframe(targetMesh, surfaceName, velArray, meshTool, colArray):
	if (!targetMesh.has_meta("orgMesh")):
		var nm = Mesh.new()
		meshTool.commit_to_surface(nm)
		nm.surface_set_name(0, surfaceName)
		
		targetMesh.set_meta("COL", {surfaceName: colArray})
		targetMesh.set_meta("VEL", {surfaceName: velArray})
		targetMesh.set_meta("orgMesh", nm)
	else:
		meshTool.commit_to_surface(targetMesh.get_meta("orgMesh"))
		targetMesh.get_meta("orgMesh").surface_set_name(targetMesh.get_meta("orgMesh").get_surface_count() - 1, surfaceName)
		targetMesh.get_meta("VEL")[surfaceName] = velArray
		targetMesh.get_meta("COL")[surfaceName] = colArray
	
	var ids = surfaceNameToId(targetMesh, surfaceName)
	targetMesh.surface_set_material(int(ids.x), editedMaterial)
	surfaceGUITest(selectedNodes[dock.getSelSourceMeshId()].get_mesh(), dock.getSelTargetSurfaceName())

func doCancelWireframe(meshInstance, targetMesh, surfaceName):
	var ids = surfaceNameToId(targetMesh, surfaceName)
	var meshTool = MeshDataTool.new()
	meshTool.create_from_surface(targetMesh.get_meta("orgMesh"), int(ids.y))
	
	for i in range(meshTool.get_vertex_count()):
		meshTool.set_vertex_color(i, Color(0.0, 0.0, 0.0))
	#mesh
	targetMesh.surface_remove(int(ids.x))
	meshTool.commit_to_surface(targetMesh)
	targetMesh.surface_set_name(targetMesh.get_surface_count() - 1, surfaceName)	
	#meta mesh
	targetMesh.get_meta("orgMesh").surface_remove(int(ids.y))
	targetMesh.get_meta("VEL").erase(surfaceName)
	targetMesh.get_meta("COL").erase(surfaceName)
	
	if (targetMesh.get_meta("orgMesh").get_surface_count() == 0):
		targetMesh.set_meta("orgMesh", null)
		targetMesh.set_meta("VEL", null)
		targetMesh.set_meta("COL", null)
	
	surfaceGUITest(targetMesh, surfaceName)

func undoCancelWireframe(targetMesh, surfaceName, delArray, meshTool, colArray):
	undoCommitWireframe(targetMesh, surfaceName, delArray, meshTool, colArray)
	var ids = surfaceNameToId(targetMesh, surfaceName)
	generateWireframeMesh(meshTool, targetMesh, int(ids.x), surfaceName)

func doGenerateWireframe(targetMesh, surfaceName):
	var ids = surfaceNameToId(targetMesh, surfaceName)
	var meshTool = MeshDataTool.new()
	meshTool.create_from_surface(targetMesh, int(ids.x))
	#fill COL with vertex colors - we won't use VC in mesh anymore, fil VEL
	var colorArray = []
	var visibleEdges = []
	for i in range(meshTool.get_edge_count()):
		visibleEdges.append(i)
		colorArray.append(meshTool.get_vertex_color(meshTool.get_edge_vertex(i, 0)))
		colorArray.append(meshTool.get_vertex_color(meshTool.get_edge_vertex(i, 1)))
	#mesh wasn't edited before - new mesh and commit backup to it, create metadata, add VEL array to dict
	if (!targetMesh.has_meta("orgMesh")):
		var backupMesh = Mesh.new()
		meshTool.commit_to_surface(backupMesh)
		backupMesh.surface_set_name(0, surfaceName)
		targetMesh.set_meta("orgMesh", backupMesh)
		targetMesh.set_meta("VEL", {surfaceName : visibleEdges}) #Dictionary - key: surface name, value: array of int
		targetMesh.set_meta("COL", {surfaceName : colorArray}) #value: array - index: edge index, value: color
	#mesh has metadata
	else:
		meshTool.commit_to_surface(targetMesh.get_meta("orgMesh"))
		targetMesh.get_meta("orgMesh").surface_set_name(targetMesh.get_meta("orgMesh").get_surface_count() - 1, surfaceName)
		targetMesh.get_meta("VEL")[surfaceName] = visibleEdges
		targetMesh.get_meta("COL")[surfaceName] = colorArray
	
	generateWireframeMesh(meshTool, targetMesh, int(ids.x), surfaceName)
	targetMesh.surface_set_material(int(ids.x), editedMaterial)
	surfaceGUITest(targetMesh, surfaceName)