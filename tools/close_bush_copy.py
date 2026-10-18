"""Add a closed envelope using ONLY native foliage vertices and joint bindings.
Original assets remain read-only. Run build_bush_copy.gd afterwards.
ARCHIVED: the user preferred native geometry with front-face depth cutout;
this envelope simplified indentations and produced stretched/angled faces.
"""
import json
from pathlib import Path
import numpy as np
from scipy.spatial import ConvexHull
from scipy.spatial import cKDTree
from scipy.ndimage import binary_erosion
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
for source, target in [('bush_world', 'bush_custom'), ('bush_disguise', 'bush_custom_disguise')]:
    original = json.loads((ROOT/f'assets/items/{source}/worn_data.json').read_text())
    points, bindings, triangles = [], [], []
    for page in ['11', '9']:
        surface = original['surfaces'][page]
        for index, point in enumerate(surface['verts']):
            points.append(point)
            bindings.append(surface['bones'][index])
        for index in range(0, len(surface['verts']), 3):
            triangles.append((page, np.array(surface['verts'][index:index+3]),
                              np.array(surface['uvs'][index:index+3]),
                              np.array(surface['cols'][index:index+3])))
    vertices, indices = np.unique(np.array(points), axis=0, return_index=True)
    bones = np.array(bindings)[indices]
    safe_pixels = {}
    for page in ['11', '9']:
        image = np.asarray(Image.open(ROOT/f'assets/items/{source}/textures/page_{page}.png').convert('RGBA'))
        mask = (image[:,:,1] > image[:,:,0]*1.3) & (image[:,:,1] > image[:,:,2]*1.3) & (image[:,:,1] > 25) & (image[:,:,3] > 10)
        y, x = np.where(binary_erosion(mask))
        uv_points = np.stack([(x+.5)/image.shape[1],(y+.5)/image.shape[0]],axis=1)
        safe_pixels[page] = (cKDTree(uv_points),uv_points)
    shell = {p: {k: [] for k in ['verts', 'uvs', 'cols', 'bones']} for p in ['11', '9']}
    for face in ConvexHull(vertices).simplices:
        face_points = vertices[face]
        center = face_points.mean(axis=0)
        normal = np.cross(face_points[1]-face_points[0], face_points[2]-face_points[0])
        normal /= np.linalg.norm(normal)
        def score(triangle):
            _, p, _, _ = triangle
            n = np.cross(p[1]-p[0], p[2]-p[0])
            length = np.linalg.norm(n)
            return np.linalg.norm(center-p.mean(axis=0)) + .25*(1-abs(normal@n/length)) if length > 1e-8 else 1e6
        page, p, uv, color = min(triangles, key=score)
        out = shell[page]
        for index, point in zip(face, face_points):
            # Project onto an original face, keeping its painted leaves and
            # original atlas bounds instead of inventing a new texture.
            bary = np.linalg.lstsq(np.stack([p[1]-p[0], p[2]-p[0]], axis=1), point-p[0], rcond=None)[0]
            weights = np.maximum([1-bary.sum(), *bary], 0)
            weights /= weights.sum()
            # Keep the closure just inside the native cards, preserving their
            # painted silhouette. Avoid opaque black from transparent atlas edges.
            out['verts'].append((point*.985+vertices.mean(axis=0)*.015).tolist())
            projected = weights@uv
            tree, valid_uv = safe_pixels[page]
            _, nearest = tree.query(projected)
            out['uvs'].append(valid_uv[nearest].tolist())
            out['cols'].append((weights@color).tolist())
            out['bones'].append(int(bones[index]))
    original['shell_surfaces'] = shell
    original['shell_source'] = {'asset': source, 'method': 'native vertex envelope; original joint bindings and projected native UVs'}
    (ROOT/f'assets/items/{target}/worn_data.json').write_text(json.dumps(original, separators=(',', ':')))
    print(target, 'added shell triangles:', sum(len(s['verts'])//3 for s in shell.values()))
