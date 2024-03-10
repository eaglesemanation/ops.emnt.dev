from pathlib import Path
import yaml

# Group for users that will be used as collaborative space
c.JupyterHub.load_groups["collaborative"] = []

# Default to home instead of spawning to choose project
c.JupyterHub.default_url = "/hub/home"

projects_yaml = Path(__file__).parent.resolve().joinpath("jupyterhub_config.d/projects.yaml")
with projects_yaml.open() as f:
    project_config = yaml.safe_load(f)

for project_name, project in project_config["projects"].items():
    # get the members of the project
    members = project.get("members", [])
    print(f"Adding project {project_name} with members {members}")
    # add them to a group for the project
    c.JupyterHub.load_groups[project_name] = members
    # define a new user for the collaboration
    collab_user = f"{project_name}-collab"
    # add the collab user to the 'collaborative' group
    # so we can identify it as a collab account
    c.JupyterHub.load_groups["collaborative"].append(collab_user)

    # finally, grant members of the project collaboration group
    # access to the collab user's server,
    # and the admin UI so they can start/stop the server
    c.JupyterHub.load_roles.append(
        {
            "name": f"collab-access-{project_name}",
            "scopes": [
                f"access:servers!user={collab_user}",
                f"admin:servers!user={collab_user}",
                "admin-ui",
                f"list:users!user={collab_user}",
            ],
            "groups": [project_name],
        }
    )

def pre_spawn_hook(spawner):
    group_names = {group.name for group in spawner.user.groups}
    if "collaborative" in group_names:
        spawner.log.info(f"Enabling RTC for user {spawner.user.name}")
        spawner.args.append("--LabApp.collaborative=True")

c.Spawner.pre_spawn_hook = pre_spawn_hook
