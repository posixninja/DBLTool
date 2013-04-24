//
//  main.cpp
//  dloadtool
//
//  Created by Joshua Hill on 1/30/13.
//  Copyright (c) 2013 __MyCompanyName__. All rights reserved.
//

#include <iostream>
#include <mach/mach.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>
#include <CoreFoundation/CoreFoundation.h>

#include "usb.h"
#include "util.h"
#include "dbl.h"

void usage() {
    printf("Usage: dbltool -b <bbticket> -o <osbl> -a <amss>\n");
    exit(1);
}

int main (int argc, const char * argv[]) {
    int arg = 1;
    UInt8 config = 0;
    USBDevice device;
    USBInterface iface;
    const char* osbl = NULL;
    const char* amss = NULL;
    const char* bbticket = NULL;
    
    if(argc != 7) {
        usage();
    }
    
    while(arg < argc) {
        if(strcmp(argv[arg], "-b") == 0) {
            arg++;
            bbticket = argv[arg++];
            continue;
            
        } else if(strcmp(argv[arg], "-o") == 0) {
            arg++;
            osbl = argv[arg++];
            continue;
            
        } else if(strcmp(argv[arg], "-a") == 0) {
            arg++;
            amss = argv[arg++];
            continue;
            
        } else {
            usage();
        }
    }
    
    printf("Starting DBLTool\n");
    if(!bbticket || !osbl || !amss) {
        usage();
    }
    
    //Vendor ID: 0x5c6
    //Product ID: 0x900e
    device = OpenDevice(0x5c6, 0x900e);
    if(device) {
        printf("Device Opened\n");
        config = SetConfiguration(device, 1);
        if(config == 1) {
            printf("Configuration %hhx set\n", config);
            iface = OpenInterface(device, 0, 0);
            if(iface) {
                printf("Interface Opened\n");
                /*
                if(argc > 1) {
                    int i = 0;
                    int v = 0;
                    unsigned char input[0x200];
                    unsigned char output[0x200];
                    printf("Recv:\n");
                    UInt32 insize = sizeof(input);
                    ReadBulk(iface, 1, input, &insize);
                    if(insize > 0) {
                       hexdump(input, insize);
                    }
                    for(v = 1; v < argc; v++) {
                        const char* arg = (const char*) argv[v];
                        unsigned int size = strlen(arg) / 2;
                        memset(output,'\0', sizeof(output));
                        memset(input, '\0', sizeof(input));
                        for(i = 0; i < size; i++) {
                            unsigned int byte = 0;
                            sscanf(arg, "%02x", &byte);
                            output[i] = byte;
                            arg += 2;
                        }

                        printf("Send:\n");
                        if(size > 0) {
                            WriteBulk(iface, 2, output, size);
                            hexdump(output, size);
                        } else {
                            fprintf(stderr, "Invalid size\n");
                        }
                    
                        printf("Recv:\n");
                        UInt32 insize = sizeof(input);
                        ReadBulk(iface, 1, input, &insize);
                        if(insize > 0) {
                            hexdump(input, insize);
                        }
                    }
                    
                } else {
                 */
                    int done = 0;
                    unsigned char input[0x2000];
                    dbl_header_t* request = NULL;
                    dbl_execute_resp_t* response = NULL;
                    
                    while(!done) {
                        printf("Recv:\n");
                        memset(input, '\0', 0x2000);
                        UInt32 insize = sizeof(input);
                        ReadBulk(iface, 1, input, &insize);
                        if(insize > 0) {
                            if(insize == -1) done = 1;
                            hexdump(input, insize);
                            request = (dbl_header_t*) input;
                            switch(request->code) {
                                case DBL_PARAM_REQ:
                                    printf("Got DBL Parameter request\n");
                                    dbl_send_params(iface, (dbl_param_req_t*) input);
                                    break;
                                    
                                case DBL_MEMORY_REQ:
                                    printf("Got DBL Memory Request\n");
                                    dbl_send_memory(iface, (dbl_memory_req_t*) input, osbl, amss);
                                    break;
                                    
                                case DBL_MEMORY_RESP:
                                    printf("Got DBL Memory Response\n");
                                    dbl_send_execute(iface);
                                    break;
                                    
                                case DBL_EXECUTE_REQ:
                                    printf("Got DBL Execute Request\n");
                                    break;
                                    
                                case DBL_EXECUTE_RESP:
                                    printf("Got DBL Execute Response\n");
                                    response = (dbl_execute_resp_t*) input;
                                    if(response->file == 0x1) done = 1;
                                    break;
                                    
                                case DBL_BBTICKET_REQ:
                                    printf("Got BBTicket Request\n");
                                    dbl_send_bbticket_params(iface);
                                    break;
                                    
                                case DBL_BBTICKET_DATA_REQ:
                                    printf("Got BBTicket Data Request\n");
                                    dbl_send_bbticket_memory(iface, (dbl_bbticket_data_req_t*) request, bbticket);
                                    break;
                                    
                                case DBL_BBTICKET_EXECUTE_REQ:
                                    printf("Got BBTicket Execute Request\n");
                                    dbl_send_bbticket_execute(iface);
                                    break;
                                    
                                case DBL_BBTICKET_EXECUTE_RESP:
                                    printf("Got BBTicket Execute Response\n");
                                    break;
                                    
                                case DBL_BBTICKET_RESULT:
                                    printf("Got BBTicket Result\n");
                                    dbl_send_execute(iface);
                                    break;
                                    
                                default:
                                    printf("Got Unknown Request\n");
                                    break;
                            }
                        }
                    //}
                }
                printf("Closing Interface\n");
                CloseInterface(iface);
            
            } else {
                fprintf(stderr, "Couldn't open device interface\n");
            }
        }
        
        
        CloseDevice(device);
    }
    
    return 0;
}

