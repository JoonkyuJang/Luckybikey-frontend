# ----request_route()-------------------------------------------------------------------------
from firebase_admin import initialize_app, firestore, credentials
from firebase_functions import https_fn, options
from google.cloud.firestore import CollectionReference

from typing import Dict, List, TypedDict, Set, Tuple
from geopy.distance import distance
import heapq
from numpy import array, dot

import asyncio
import multiprocessing
from multiprocessing import Queue, Process

import os

AStarReturn = TypedDict(
    "AStarReturn", {"path": List[Dict[str, float]], "full_distance": float}
)
RequestRouteReturn = TypedDict(
    "RequestRouteReturn",
    {
        "route": List[Dict[str, float]],
        "path": List[Dict[str, float]],
        "full_distance": float,
    },
)

initialize_app()
firestore_client = firestore.client()
os.environ["GOOGLE_CLOUD_PROJECT"] = "luckybikey-25"

TILES_COLLECTION = "node_tiles"
NODES_COLLECTION = "nodes"
NUM_PROCESSES = 9


class Node:
    def __init__(self, id: int, geometry: Dict[str, float], connections, parent=None):
        self.id: int = id
        self.lat: float = geometry["lat"]
        self.lon: float = geometry["lon"]
        self.connections = connections
        self.g: float = 0
        self.h: float = 90000
        self.f: float = 0
        self.parent = parent

    def __lt__(self, other):
        return self.f < other.f

    def __eq__(self, other):
        return self.id == other.id


async def firestore_get(tile_input_queue: Queue, node_output_queue: Queue):
    try:
        collection_ref = firestore_client.collection(TILES_COLLECTION)
        while True:
            tile = tile_input_queue.get()
            if tile is None:
                break
            if tile == "BUFFER":
                continue
            print(
                f"Process {multiprocessing.current_process().name} started pushing nodes into the queue"
            )
            for doc in (
                collection_ref.document(tile).collection(NODES_COLLECTION).stream()
            ):
                node = Node(
                    int(doc.id),
                    doc.to_dict(),
                    {int(k): v for k, v in doc.to_dict()["connections"].items()},
                )
                node_output_queue.put(node)
                # print(f"Process {multiprocessing.current_process().name} pushed node {doc.id} into the queue")
            print(
                f"{multiprocessing.current_process().name} finished pushing {tile} nodes into the queue"
            )
    except Exception as e:
        print(f"Error in process {multiprocessing.current_process().name}: {e}")
    finally:
        print(f"{multiprocessing.current_process().name} exiting")
        tile_input_queue.close()


async def node_put(node_queue, node_map):
    try:
        while True:
            data = node_queue.get()
            if data is None:
                break
            node_map[data.id] = data
            # print(f"Main process got node {data.id} from the queue")
    except Exception as e:
        print(f"Error in main process: {e}")
    finally:
        print("Main process exiting")
        node_queue.close()


def getter(tile_input_queue, node_output_queue):
    # run the get function in the child process
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    loop.run_until_complete(firestore_get(tile_input_queue, node_output_queue))
    loop.close()


def putter(node_queue: Queue, node_map: Dict[int, Node]):
    # run the put function in the main process
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    loop.run_until_complete(node_put(node_queue, node_map))
    loop.close()


def create_node_map(
    node_map: Dict[int, Node],
    open_tiles: Set,
    start_lat: float,
    start_lon: float,
    end_lat: float,
    end_lon: float,
):
    first_tile, last_tile, tiles = get_tiles(
        start_lat, start_lon, end_lat, end_lon, open_tiles
    )

    getter_processes = []
    node_output_queue = Queue()

    for _ in range(NUM_PROCESSES):
        tile_input_queue = Queue()
        p = Process(target=getter, args=(tile_input_queue, node_output_queue))
        getter_processes.append({"process": p, "tile_input_queue": tile_input_queue})
        p.start()
        print(f"Process {p.name} started")

    # Prioritize the first and last tiles to be fetched
    # to ensure that the start and end points are covered
    getter_processes[0]["tile_input_queue"].put(first_tile)
    getter_processes[0]["tile_input_queue"].put(last_tile)
    getter_processes[0]["tile_input_queue"].put("BUFFER")

    while True:
        if getter_processes[0]["tile_input_queue"].empty():
            break

    putter_process = Process(target=putter, args=(node_output_queue, node_map))
    putter_process.start()
    # print(f"Process {putter_process.name} started")

    while True:
        if node_output_queue.empty():
            break

    # todo: optimize order of tiles to fetch based on the start and end points
    for i, tile in enumerate(tiles):
        getter_processes[i % (NUM_PROCESSES - 1) + 1]["tile_input_queue"].put(tile)

    return getter_processes[0], {
        "process": putter_process,
        "node_output_queue": node_output_queue,
    }


def get_tiles(
    start_lat: float, start_lon: float, end_lat: float, end_lon: float, open_tiles: Set
) -> Tuple[str, str, List[str]]:
    smallest_lat = min(start_lat, end_lat)
    smallest_lon = min(start_lon, end_lon)
    largest_lat = max(start_lat, end_lat)
    largest_lon = max(start_lon, end_lon)

    first_tile = f"seoul_tile_lat_{int(start_lat * 100)}_lng_{int(start_lon * 100)}"
    last_tile = f"seoul_tile_lat_{int(end_lat * 100)}_lng_{int(end_lon * 100)}"
    open_tiles.add(first_tile)
    open_tiles.add(last_tile)

    tiles = []
    for lat in range(int(smallest_lat * 100), int(largest_lat * 100) + 1):
        for lon in range(int(smallest_lon * 100), int(largest_lon * 100) + 1):
            if lat == int(start_lat * 100) and lon == int(start_lon * 100):
                continue
            if lat == int(end_lat * 100) and lon == int(end_lon * 100):
                continue
            tile = f"seoul_tile_lat_{lat}_lng_{lon}"
            tiles.append(tile)
            open_tiles.add(tile)

    return first_tile, last_tile, tiles


def get_node(
    node_map, id: int, lat: float, lon: float, open_tiles: Set, priority_queue
) -> Node:
    tile = f"seoul_tile_lat_{int(lat * 100)}_lng_{int(lon * 100)}"
    # Firestore에서 노드 생성
    if id in node_map:
        return node_map[id]
    elif tile in open_tiles:
        while True:
            if id in node_map:
                return node_map[id]
    else:
        # tile이 open_tiles에 없으면 getter process에 요청
        priority_queue.put(tile)
        open_tiles.add(tile)
        while True:
            if id in node_map:
                return node_map[id]


def get_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    # 두 지점 사이의 거리 계산
    coords1 = (lat1, lon1)
    coords2 = (lat2, lon2)
    return round(distance(coords1, coords2).m, 3)


def heuristic_Manhattan_distance(cur_node: Node, end_node: Node) -> float:

    # 거리 계산
    h = distance((cur_node.lat, cur_node.lon), (end_node.lat, end_node.lon)).meters
    return h


def heuristic_preference_distance(
    cur_node: Node, end_node: Node, group_road_type, group_preference
) -> float:
    manhattan_dist = heuristic_Manhattan_distance(cur_node, end_node)
    # next node의 해당 group의 preference 추가
    # print(group_road_type)

    feature_num = len(
        group_preference
    )  # feature_num을 고정 값인 preference를 다 더한 값을 사용하면 어떻게 될까.. 음수가 될 수도 있긴한데 음수를 0으로 빼버리면?
    pref_sum = abs(sum(group_preference))
    lt = array(group_road_type)
    gp = array(group_preference)
    road_preference = dot(lt, gp)

    if all(
        abs(x) < 0.3 for x in group_preference
    ):  # group의 preference이기 때문에 이미 0.3보다 작은 애들은 preference를 끄고 진행한다고 생각하고 코드 짜기
        pref_sum = feature_num

    # feature 개수로 나눈 대로 scaling
    pref_dist = manhattan_dist - (manhattan_dist / pref_sum) * road_preference
    if pref_dist < 0:
        pref_dist = 0  # 휴리스틱이 항상 0 이상이도록

    return pref_dist


def astar_road_finder2(
    node_map,
    start_node: Node,
    end_node: Node,
    user_taste: bool,
    user_group: str,
    group_preference: List,
    open_tiles: Set,
    priority_queue,
) -> AStarReturn:
    # A* 알고리즘을 사용하여 시작 노드에서 도착 노드까지의 최단 경로 찾기
    open_list: List[Node] = []
    closed_set = set()
    start_node.h = heuristic_Manhattan_distance(start_node, end_node)
    heapq.heappush(open_list, start_node)

    while open_list != []:
        cur_node = heapq.heappop(open_list)
        closed_set.add(cur_node.id)

        if cur_node == end_node:
            final_road = []
            final_path = [
                {"node_id": cur_node.id, "lat": cur_node.lat, "lon": cur_node.lon}
            ]
            total_distance = cur_node.g
            while cur_node is not None:
                final_road.append(
                    {"node_id": cur_node.id, "lat": cur_node.lat, "lon": cur_node.lon}
                )
                if cur_node.parent is not None:
                    final_path += [
                        {
                            "node_id": cur_node.id,
                            "lat": branch["lat"],
                            "lon": branch["lon"],
                        }
                        for branch in cur_node.connections[cur_node.parent.id][
                            "routes"
                        ][0]["branch"][1:]
                    ]
                cur_node = cur_node.parent
            return {
                "route": final_road[::-1],
                "path": final_path[::-1],
                "full_distance": total_distance,
            }

        for id, inner_dict in cur_node.connections.items():
            new_node = get_node(
                node_map,
                id,
                inner_dict["lat"],
                inner_dict["lon"],
                open_tiles,
                priority_queue,
            )

            if new_node.id in closed_set:
                continue
            if new_node in open_list:
                if (cur_node.g + inner_dict["distance"]) >= new_node.g:
                    continue
            new_node.g = cur_node.g + inner_dict["distance"]
            if user_taste:
                new_node.h = heuristic_preference_distance(
                    new_node,
                    end_node,
                    inner_dict["clusters"][user_group]["attributes"],
                    group_preference,
                )
            else:
                new_node.h = heuristic_Manhattan_distance(new_node, end_node)
            new_node.f = new_node.g + new_node.h
            new_node.parent = cur_node
            heapq.heappush(open_list, new_node)

    # 길이 연결되지 않았으면 에러 발생
    raise https_fn.HttpsError(
        code=https_fn.FunctionsErrorCode.INTERNAL,
        message="No route was found between the start and end points.",
    )


def get_nearest_node2(node_map, lat: float, lon: float) -> tuple[int, float]:
    # 선형 검색으로 가장 가까운 노드 탐색. TODO 더 가까운 알고리즘 있으면 대체할 것
    # 기준 좌표 부근에서 후보 노드들 query
    docs = []

    for node in node_map.values():
        if (
            lat - 0.005 <= node.lat <= lat + 0.005
            and lon - 0.005 < node.lon < lon + 0.005
        ):
            docs.append(node)

    # 해당 범위에 노드가 없으면 에러 발생
    if not docs:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message="No nodes near the end point were found.",
        )

    # 후보 노드들 중 가장 가까운 노드 찾기
    min = float("inf")
    node_min: Node = None
    for node in docs:
        dist = get_distance(node.lat, node.lon, lat, lon)
        if dist < min:
            node_min = node
            min = dist

    return (node_min, min)


def exit_processes(getter_processes, putter_process):
    for p in getter_processes:
        p["tile_input_queue"].put(None)
        p["tile_input_queue"].close()

    for p in getter_processes:
        p["process"].join()

    putter_process["node_output_queue"].put(None)
    putter_process["node_output_queue"].close()
    putter_process["process"].join()


@https_fn.on_call(
    timeout_sec=120, memory=options.MemoryOption.GB_4, region="asia-northeast3"
)
def request_route(req: https_fn.CallableRequest) -> RequestRouteReturn:
    try:  # 요청 데이터 파싱
        start_point = req.data["StartPoint"]
        end_point = req.data["EndPoint"]
        user_taste = req.data["UserTaste"]
        user_group = req.data["UserGroup"]
        group_preference = req.data["GroupPreference"]
    except KeyError as e:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message=(f"Missing argument '{e}' in request data."),
        )

    try:  # 요청 데이터 유효성 검사
        start_lat = start_point["lat"]
        start_lon = start_point["lon"]
    except KeyError as e:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message=(f"Missing argument '{e}' in start point."),
        )

    try:  # 요청 데이터 유효성 검사
        end_lat = end_point["lat"]
        end_lon = end_point["lon"]
    except KeyError as e:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message=(f"Missing argument '{e}' in end point."),
        )

    try:  # 요청 데이터 타입 변환
        start_lat = float(start_lat)
        start_lon = float(start_lon)
        end_lat = float(end_lat)
        end_lon = float(end_lon)
        user_taste = bool(user_taste)
        user_group = str(user_group)
        group_preference = list(group_preference)
    except ValueError as e:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message=(e.args[0]),
        )

    try:
        # Spawn subprocesses to fetch nodes from Firestore
        # and spawn a process to put nodes into the node_map
        # dynamically change the priority of tiles to fetch based on the start and end points
        # change the number of processes to fetch nodes from Firestore
        # collection_ref = firestore_client.collection("tiles")
        print("Creating node map...")
        node_map = multiprocessing.Manager().dict()
        open_tiles = set()
        getter_process, putter_process = create_node_map(
            node_map, open_tiles, start_lat, start_lon, end_lat, end_lon
        )
        priority_queue = getter_process["tile_input_queue"]
        print("Node map created.")
        print(len(node_map))

    except Exception as e:
        getter_process["tile_input_queue"].put(None)
        getter_process["tile_input_queue"].close()
        getter_process["process"].join()
        putter_process["node_output_queue"].put(None)
        putter_process["node_output_queue"].close()
        putter_process["process"].join()
        # exit_processes(getter_processes, putter_process)
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f"Failed to create node map. Error: {e.args[0]}",
        )

    try:  # 시작점에서 가장 가까운 노드 찾기
        nearest_start_node, start_dist = get_nearest_node2(
            node_map, start_lat, start_lon
        )
        print(f"Nearest start node: {nearest_start_node.id}, distance: {start_dist}")
    except Exception as e:
        getter_process["tile_input_queue"].put(None)
        getter_process["tile_input_queue"].close()
        getter_process["process"].join()
        putter_process["node_output_queue"].put(None)
        putter_process["node_output_queue"].close()
        putter_process["process"].join()
        # exit_processes(getter_processes, putter_process)
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f"No nodes near the start point were found. Error: {e.args}",
        )

    try:  # 도착점에서 가장 가까운 노드 찾기
        nearest_end_node, end_dist = get_nearest_node2(node_map, end_lat, end_lon)
        print(f"Nearest end node: {nearest_end_node.id}, distance: {end_dist}")
    except Exception as e:
        getter_process["tile_input_queue"].put(None)
        getter_process["tile_input_queue"].close()
        getter_process["process"].join()
        putter_process["node_output_queue"].put(None)
        putter_process["node_output_queue"].close()
        putter_process["process"].join()
        # exit_processes(getter_processes, putter_process)
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f"No nodes near the end point were found. Error: {e.args}",
        )

    try:  # 시작노드-도착노드 길찾기
        print("Finding route...")
        result = astar_road_finder2(
            node_map,
            start_node=nearest_start_node,
            end_node=nearest_end_node,
            user_taste=user_taste,
            user_group=user_group,
            group_preference=group_preference,
            open_tiles=open_tiles,
            priority_queue=priority_queue,
        )
        getter_process["tile_input_queue"].put(None)
        getter_process["tile_input_queue"].close()
        getter_process["process"].join()
        putter_process["node_output_queue"].put(None)
        putter_process["node_output_queue"].close()
        putter_process["process"].join()
        # exit_processes(getter_processes, putter_process)
    except Exception as e:
        getter_process["tile_input_queue"].put(None)
        getter_process["tile_input_queue"].close()
        getter_process["process"].join()
        putter_process["node_output_queue"].put(None)
        putter_process["node_output_queue"].close()
        putter_process["process"].join()
        # exit_processes(getter_processes, putter_process)
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f"An error occured while running a star. Error: {repr(e)}",
        )

    # 시작점과 도착점을 최종 경로에 추가
    try:
        start_point_node = [{"node_id": None, "lat": start_lat, "lon": start_lon}]
        end_point_node = [{"node_id": None, "lat": end_lat, "lon": end_lon}]
        # route = start_point_node + result["route"] + end_point_node
        path = start_point_node + result["path"] + end_point_node
        full_distance = start_dist + result["full_distance"] + end_dist
        print("Returning route")
        return {"path": path, "full_distance": full_distance}
    except Exception as e:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=(e.args[0]),
        )


# ---------------------------------------------------------------------------------------------------


def dot_dict(dict_: dict):
    class DotDict(dict):
        __getattr__ = dict.__getitem__
        __setattr__ = dict.__setitem__
        __delattr__ = dict.__delitem__

    return DotDict(dict_)


if __name__ == "__main__":
    route = request_route(
        dot_dict(
            {
                "data": {
                    "StartPoint": {"lat": 37.5572, "lon": 126.9619},
                    "EndPoint": {"lat": 37.5605, "lon": 126.9773},
                    "UserTaste": True,
                    "UserGroup": 0,
                    "GroupPreference": [
                        0,
                        -0.778,
                        0.667,
                        -0.556,
                        0.444,
                        -0.889,
                        -0.111,
                        0.667,
                    ],
                }
            }
        )
    )
    breakpoint()


# ----original version--------------------------------------------------------------------------
# #----request_route()-------------------------------------------------------------------------
# from firebase_admin import initialize_app, firestore
# from firebase_functions import https_fn, options
# from google.cloud.firestore import CollectionReference

# from typing import Dict, List, TypedDict
# from geopy.distance import distance
# import heapq
# from numpy import array, dot

# AStarReturn = TypedDict("AStarReturn", {"path": List[Dict[str, float]], "full_distance": float})
# RequestRouteReturn = TypedDict("RequestRouteReturn", {"route": List[Dict[str, float]], "path": List[Dict[str, float]], "full_distance": float})


# initialize_app()
# firestore_client = firestore.client()


# class Node:
#     def __init__(self, id: int, geometry: Dict[str, float], connections, parent=None):
#         self.id: int = id
#         self.lat: float = geometry["lat"]
#         self.lon: float = geometry["lon"]
#         self.connections = connections
#         self.g: float = 0
#         self.h: float = 90000
#         self.f: float = 0
#         self.parent = parent

#     def __lt__(self, other):
#         return self.f < other.f

#     def __eq__(self, other):
#         return self.id == other.id


# def create_node_map(collection_ref: CollectionReference, start_lat: float, start_lon: float, end_lat: float, end_lon: float):
#     # Firestore에서 노드 맵 생성
#     smallest_lat = min(start_lat, end_lat)
#     smallest_lon = min(start_lon, end_lon)
#     largest_lat = max(start_lat, end_lat)
#     largest_lon = max(start_lon, end_lon)

#     tiles = []
#     for lat in range(int(smallest_lat * 100), int(largest_lat * 100) + 1):
#         for lon in range(int(smallest_lon * 100), int(largest_lon * 100) + 1):
#             tiles.append(f"seoul_tile_lat_{lat}_lng_{lon}")

#     node_map = {}
#     for tile in tiles:
#         for doc in collection_ref.document(tile).collection('nodes').stream():
#             node_map[int(doc.id)] = Node(int(doc.id), doc.to_dict(), doc.to_dict()["connections"])

#     for node in node_map.values():
#         try:
#             node.connections = {int(k): {"node": node_map[int(k)], "routes": v["routes"], "clusters": v["clusters"], "distance": v["distance"]} for k, v in node.connections.items()}
#         except KeyError:
#             node.connections = {int(k): {"node": None, "routes": v["routes"], "clusters": v["clusters"], "distance": v["distance"], "lat": v["lat"], "lon": v["lon"]} for k, v in node.connections.items()}

#     return node_map

# def get_new_tile(collection_ref: CollectionReference, node_map: Dict[int, Node], lat: float, lon: float):
#     new_tile = {}
#     for doc in collection_ref.document(f"seoul_tile_lat_{int(lat*100)}_lng_{int(lon*100)}").collection(nodes).stream():
#         new_tile[int(doc.id)] = Node(int(doc.id), doc.to_dict(), doc.to_dict()["connections"])

#     return new_tile

# def update_node_map(node_map: Dict[int, Node], new_tile: Dict[int, Node]):
#     for node in new_tile.values():
#         for k, v in node.connections.items():
#             if k in new_tile:
#                 # connection node is within the same tile
#                 node.connections[int(k)] = {"node": new_tile[int(k)], "routes": v["routes"], "clusters": v["clusters"], "distance": v["distance"]}
#             elif k in node_map:
#                 # connection node is in node_map
#                 node.connections[int(k)] = {"node": node_map[int(k)], "routes": v["routes"], "clusters": v["clusters"], "distance": v["distance"]}
#                 node_map[k].connections[node.id]["node"] = node
#             else:
#                 node.connections[int(k)] =  {"node": None, "routes": v["routes"], "clusters": v["clusters"], "distance": v["distance"], "id": v["id"], "lat": v["lat"], "lon": v["lon"]}


# def get_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
#     # 두 지점 사이의 거리 계산
#     coords1 = (lat1, lon1)
#     coords2 = (lat2, lon2)
#     return round(distance(coords1, coords2).m, 3)


# def heuristic_Manhattan_distance(cur_node: Node, end_node: Node) -> float:

#     # 거리 계산
#     h = distance((cur_node.lat, cur_node.lon), (end_node.lat, end_node.lon)).meters
#     return h


# def heuristic_preference_distance(cur_node: Node, end_node: Node, group_road_type, group_preference) -> float:
#     manhattan_dist = heuristic_Manhattan_distance(cur_node, end_node)
#     # next node의 해당 group의 preference 추가
#     # print(group_road_type)

#     feature_num = len(group_preference)  # feature_num을 고정 값인 preference를 다 더한 값을 사용하면 어떻게 될까.. 음수가 될 수도 있긴한데 음수를 0으로 빼버리면?
#     pref_sum = abs(sum(group_preference))
#     lt = array(group_road_type)
#     gp = array(group_preference)
#     road_preference = dot(lt, gp)

#     if all(abs(x) < 0.3 for x in group_preference):  # group의 preference이기 때문에 이미 0.3보다 작은 애들은 preference를 끄고 진행한다고 생각하고 코드 짜기
#         pref_sum = feature_num

#     # feature 개수로 나눈 대로 scaling
#     pref_dist = manhattan_dist - (manhattan_dist / pref_sum) * road_preference
#     if pref_dist < 0:
#         pref_dist = 0  # 휴리스틱이 항상 0 이상이도록

#     return pref_dist


# def astar_road_finder2(node_map, start_node: Node, end_node: Node, user_taste: bool, user_group: str, group_preference: List) -> AStarReturn:
#     # A* 알고리즘을 사용하여 시작 노드에서 도착 노드까지의 최단 경로 찾기
#     open_list: List[Node] = []
#     closed_set = set()
#     start_node.h = heuristic_Manhattan_distance(start_node, end_node)
#     heapq.heappush(open_list, start_node)

#     while open_list != []:
#         cur_node = heapq.heappop(open_list)
#         closed_set.add(cur_node.id)

#         if cur_node == end_node:
#             final_road = []
#             final_path = [{"node_id": cur_node.id, "lat": cur_node.lat, "lon": cur_node.lon}]
#             total_distance = cur_node.g
#             while cur_node is not None:
#                 final_road.append({"node_id": cur_node.id, "lat": cur_node.lat, "lon": cur_node.lon})
#                 if cur_node.parent is not None:
#                     final_path += [{"node_id": cur_node.id, "lat": branch["lat"], "lon": branch["lon"]} for branch in cur_node.connections[cur_node.parent.id]["routes"][0]["branch"][1:]]
#                 cur_node = cur_node.parent
#             return {"route": final_road[::-1], "path": final_path[::-1], "full_distance": total_distance}

#         new_nodes = {}
#         for id, inner_dict in cur_node.connections.items():
#             new_node = inner_dict["node"]
#             if new_node is None:
#                 if int(inner_dict["id"]) in new_nodes:
#                     continue
#                 new_nodes.update(get_new_tile(collection_ref, node_map, inner_dict["lat"], inner_dict["lon"]))

#         update_node_map(node_map, new_nodes)

#         for id, inner_dict in cur_node.connections.items():
#             new_node = inner_dict["node"]

#             if new_node.id in closed_set:
#                 continue
#             if new_node in open_list:
#                 if (cur_node.g + inner_dict["distance"]) >= new_node.g:
#                     continue
#             new_node.g = cur_node.g + inner_dict["distance"]
#             if user_taste:
#                 new_node.h = heuristic_preference_distance(new_node, end_node, inner_dict["clusters"][user_group]["attributes"], group_preference)
#             else:
#                 new_node.h = heuristic_Manhattan_distance(new_node, end_node)
#             new_node.f = new_node.g + new_node.h
#             new_node.parent = cur_node
#             heapq.heappush(open_list, new_node)


#     # 길이 연결되지 않았으면 에러 발생
#     raise https_fn.HttpsError(
#         code=https_fn.FunctionsErrorCode.INTERNAL,
#         message="No route was found between the start and end points.",
#     )


# def get_nearest_node2(node_map, lat: float, lon: float) -> tuple[int, float]:
#     # 선형 검색으로 가장 가까운 노드 탐색. TODO 더 가까운 알고리즘 있으면 대체할 것
#     # 기준 좌표 부근에서 후보 노드들 query
#     docs = []

#     for node in node_map.values():
#         if lat - 0.005 <= node.lat <= lat + 0.005 and lon - 0.005 < node.lon <lon + 0.005 :
#             docs.append(node)


#     # 해당 범위에 노드가 없으면 에러 발생
#     if not docs:
#         raise https_fn.HttpsError(
#             code=https_fn.FunctionsErrorCode.INTERNAL,
#             message="No nodes near the end point were found.",
#         )

#     # 후보 노드들 중 가장 가까운 노드 찾기
#     min = float("inf")
#     node_min_id: int = -1
#     for node in docs:
#         dist = get_distance(node.lat, node.lon, lat, lon)
#         if dist < min:
#             node_min_id = node.id
#             min = dist

#     return (node_min_id, min)


# def create_node2(node_map, id: int) -> Node:
#     # Firestore에서 노드 생성
#     node = node_map[id]
#     return node


# @https_fn.on_call(timeout_sec=120, memory=options.MemoryOption.GB_1, region="asia-northeast3")
# def request_route(req: https_fn.CallableRequest) -> RequestRouteReturn:
#     try:  # 요청 데이터 파싱
#         start_point = req.data["StartPoint"]
#         end_point = req.data["EndPoint"]
#         user_taste = req.data["UserTaste"]
#         user_group = req.data["UserGroup"]
#         group_preference = req.data["GroupPreference"]
#     except KeyError as e:
#         raise https_fn.HttpsError(
#             code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
#             message=(f"Missing argument '{e}' in request data."),
#         )

#     try:  # 요청 데이터 유효성 검사
#         start_lat = start_point["lat"]
#         start_lon = start_point["lon"]
#     except KeyError as e:
#         raise https_fn.HttpsError(
#             code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
#             message=(f"Missing argument '{e}' in start point."),
#         )

#     try:  # 요청 데이터 유효성 검사
#         end_lat = end_point["lat"]
#         end_lon = end_point["lon"]
#     except KeyError as e:
#         raise https_fn.HttpsError(
#             code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
#             message=(f"Missing argument '{e}' in end point."),
#         )

#     try:  # 요청 데이터 타입 변환
#         start_lat = float(start_lat)
#         start_lon = float(start_lon)
#         end_lat = float(end_lat)
#         end_lon = float(end_lon)
#         user_taste = bool(user_taste)
#         user_group = str(user_group)
#         group_preference = list(group_preference)
#     except ValueError as e:
#         raise https_fn.HttpsError(
#             code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
#             message=(e.args[0]),
#         )

#     try:
#         collection_ref = firestore_client.collection("node_tiles")
#         node_map = create_node_map(collection_ref, start_lat, start_lon, end_lat, end_lon)
#     except Exception as e:
#         raise https_fn.HttpsError(
#             code=https_fn.FunctionsErrorCode.INTERNAL,
#             message=f"Failed to create node map. Error: {e.args[0]}",
#         )

#     try:  # 시작점에서 가장 가까운 노드 찾기
#         nearest_start_node_id, start_dist = get_nearest_node2(node_map, start_lat, start_lon)
#         nearest_start_node = create_node2(node_map, nearest_start_node_id)
#     except Exception as e:
#         raise https_fn.HttpsError(
#             code=https_fn.FunctionsErrorCode.INTERNAL,
#             message=f"No nodes near the start point were found. Error: {e.args}",
#         )

#     try:  # 도착점에서 가장 가까운 노드 찾기
#         nearest_end_node_id, end_dist = get_nearest_node2(node_map, end_lat, end_lon)
#         nearest_end_node = create_node2(node_map, nearest_end_node_id)
#     except Exception as e:
#         raise https_fn.HttpsError(
#             code=https_fn.FunctionsErrorCode.INTERNAL,
#             message=f"No nodes near the end point were found. Error: {e.args}",
#         )

#     try:  # 시작노드-도착노드 길찾기
#         result = astar_road_finder2(node_map, start_node=nearest_start_node, end_node=nearest_end_node, user_taste=user_taste, user_group=user_group, group_preference=group_preference)
#     except Exception as e:
#         raise https_fn.HttpsError(
#             code=https_fn.FunctionsErrorCode.INTERNAL,
#             message=f"An error occured while running a star. Error: {repr(e)}",
#         )

#     # 시작점과 도착점을 최종 경로에 추가
#     try:
#         start_point_node = [{"node_id": None, "lat": start_lat, "lon": start_lon}]
#         end_point_node = [{"node_id": None, "lat": end_lat, "lon": end_lon}]
#         route = start_point_node + result["route"] + end_point_node
#         path = start_point_node + result["path"] + end_point_node
#         full_distance = start_dist + result["full_distance"] + end_dist
#         return {"path": path, "full_distance": full_distance}
#     except Exception as e:
#         raise https_fn.HttpsError(
#             code=https_fn.FunctionsErrorCode.INTERNAL,
#             message=(e.args[0]),
#         )
# #---------------------------------------------------------------------------------------------------


# def create_node_map(
#     node_map: Dict[int, Node],
#     open_tiles: Set,
#     start_lat: float,
#     start_lon: float,
#     end_lat: float,
#     end_lon: float,
# ):
#     first_tile, last_tile, tiles = get_tiles(
#         start_lat, start_lon, end_lat, end_lon, open_tiles
#     )

#     getter_processes = []
#     node_output_queue = Queue()

#     for _ in range(NUM_PROCESSES):
#         tile_input_queue = Queue()
#         p = Process(target=getter, args=(tile_input_queue, node_output_queue))
#         getter_processes.append({"process": p, "tile_input_queue": tile_input_queue})
#         p.start()
#         print(f"Process {p.name} started")

#     # Prioritize the first and last tiles to be fetched
#     # to ensure that the start and end points are covered
#     getter_processes[0]["tile_input_queue"].put(first_tile)
#     getter_processes[0]["tile_input_queue"].put(last_tile)

#     putter_process = Process(target=putter, args=(node_output_queue, node_map))
#     putter_process.start()
#     # print(f"Process {putter_process.name} started")

#     # todo: optimize order of tiles to fetch based on the start and end points
#     for i, tile in enumerate(tiles):
#         getter_processes[i % (NUM_PROCESSES - 1) + 1]["tile_input_queue"].put(tile)

#     for p in getter_processes[1:]:
#         p["tile_input_queue"].put(None)
#         p["tile_input_queue"].close()

#     for p in getter_processes[1:]:
#         p["process"].join()

#     return getter_processes[0], {"process": putter_process, "node_output_queue":node_output_queue}
