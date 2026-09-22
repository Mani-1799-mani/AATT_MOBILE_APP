export declare const checkPhoneRegistered: import("firebase-functions/v2/https").CallableFunction<any, Promise<{
    registered: boolean;
    collection: string;
} | {
    registered: boolean;
    collection?: undefined;
}>, unknown>;
export declare const linkPhoneToActor: import("firebase-functions/v2/https").CallableFunction<any, Promise<{
    success: boolean;
    action: "already_linked" | "linked";
    actorId: string;
}>, unknown>;
