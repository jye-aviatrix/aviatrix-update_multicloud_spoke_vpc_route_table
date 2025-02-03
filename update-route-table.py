import logging
import requests
import os
import json

requests.packages.urllib3.disable_warnings()
def main():
    TCP_TIMEOUT = 5
    HTTP_TIMEOUT = 10
    gateway_found = False

    controller_ip = os.environ.get("AVIATRIX_CONTROLLER_IP")
    controller_user = os.environ.get("AVIATRIX_USERNAME")
    controller_password = os.environ.get("AVIATRIX_PASSWORD")
    ssl_verify = bool(os.environ.get("SSL_VERIFY", "False").lower() == "true")

    with open('config.json','r') as file:
        config_data=json.load(file)        
    gw_name = config_data.get("Spoke_GW_Name")

    if not all([controller_ip, controller_user, controller_password, gw_name]):
        logging.error("Missing required environment variables or config.json.")
        return

    s = requests.Session()

    try:
        response = s.get(url=f'https://{controller_ip}/v2/api',
                          data={'action': 'get_api_token'},
                          verify=ssl_verify,
                          timeout=(TCP_TIMEOUT, HTTP_TIMEOUT))

        response.raise_for_status()

    except requests.exceptions.RequestException as e:
        logging.error(e)
        return

    logging.info(response.json())
    if not response.json().get("return", False):
        return
    else:
        token = response.json()["results"]["api_token"]
        print(f"Obtained Token: {token}\n")
        headers = {"Content-Type": "application/x-www-form-urlencoded",
                   "X-Access-Key": token}


    try:
        response = s.post(url=f'https://{controller_ip}/v1/api',
                          data={'action': 'login',
                                'username': controller_user,
                                'password': controller_password},
                          verify=ssl_verify,
                          headers=headers,
                          timeout=(TCP_TIMEOUT, HTTP_TIMEOUT))

        response.raise_for_status()

    except requests.exceptions.RequestException as e:
        logging.error(e)
        return

    logging.info(response.json())
    if not response.json().get("return", False):
        return
    else:
        print(f"Logged in to the controller successfully.\n")
        cid = response.json()["CID"]
    try:
        response = s.post(url=f'https://{controller_ip}/v1/api',
                          data={'action': 'list_primary_and_ha_spoke_gateways',
                                'CID': cid},
                          verify=ssl_verify,
                          timeout=(TCP_TIMEOUT, HTTP_TIMEOUT))
        response.raise_for_status()

    except requests.exceptions.RequestException as e:
        logging.error(e)
        return

    spoke_gw_list = response.json().get("results", [])
    for spoke in spoke_gw_list:
        if spoke.get("name", "") == gw_name:
            print(f'Gateway found: {spoke["name"]}\n')
            try:
                response = s.post(url=f'https://{controller_ip}/v1/api',
                                  data={'action': 'update_encrypted_spoke_vpc_cidrs',
                                        'CID': cid,
                                        'gateway_name': spoke["name"]},
                                  verify=ssl_verify,
                                  timeout=(TCP_TIMEOUT, HTTP_TIMEOUT))
                response.raise_for_status()
                if response.json() and response.json()["return"] == True:
                    resp = response.json().get("results", [])
                    print(f"{resp}\n")

            except requests.exceptions.RequestException as e:
                logging.error(e)
                return
            if spoke.get("transit_gw_name", "") != "":
                print(f'Gateway: {spoke["name"]} attached to the transit: {spoke["transit_gw_name"]}\n')
                try:
                    response = s.post(f"https://{controller_ip}/v1/api",
                                    data={'action': 'update_multicloud_spoke_vpc_route_table',
                                            'CID': cid,
                                            'gateway_name': spoke["name"]},
                                    verify=ssl_verify,
                                    timeout=(TCP_TIMEOUT, HTTP_TIMEOUT))
                    response.raise_for_status()

                except requests.exceptions.RequestException as e:
                    logging.error(e)
                    return

            print(response.text)
            gateway_found = True
            s.close()
            break
    if not gateway_found:
        print(f'No Gateway found with name {gw_name} or not attached to the Transit.')

    s.close()

if __name__ == "__main__":
    main()
